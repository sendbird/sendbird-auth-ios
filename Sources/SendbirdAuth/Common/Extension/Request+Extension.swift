//
//  URLPath.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/12/25.
//

import Foundation

public extension APIRequestable {
    func urlRequest(baseURL: String) -> URLRequest? {
        do {
            var components = try makeComponents(url: URL(string: baseURL))
            var request = try makeRequest(url: components.url)

            switch method { // Creat body / Query String
            case .get(let query):
                var queryMaps = query
                    .stringify()

                if let otherQueryItems = queryItems() {
                    queryMaps.merge(otherQueryItems, uniquingKeysWith: { _, defined in defined })
                }
                
                components.percentEncodedQuery = queryMaps
                    .reduce("") { result, entry in result + "&" + "\(entry.key)=\(entry.value)" }

                request.url = components.url
                
            case .post(let query), .put(let query), .delete(let query), .patch(let query):
                components.queryItems = query.stringify()
                    .filter({ $0.value != "" })
                    .map(URLQueryItem.init)
                request.url = components.url
                request.httpBody = multipart.isEmpty ? httpBody() : nil
            }

            return request
        } catch {
            return nil
        }
    }
}

public extension APIRequestable {
    func makeComponents(url: URL?) throws -> URLComponents {
        let error = AuthCoreError.networkRoutingError.asAuthError
        guard let url = url,
              var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw error
        }

        let path = self.url.encodedPath
        if path.contains("//") { throw error } // occurs when the parameter string is empty.
        
        urlComponents.percentEncodedPath += version + path
        return urlComponents
    }

    func makeRequest(url: URL?) throws -> URLRequest {
        guard let url = url else { throw AuthCoreError.networkRoutingError.asAuthError }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        return request
    }

    func queryItems() -> [String: String]? {
        return toDictionary(keyStrategy: keyEncodingStrategy)?.stringify()
    }

    func httpBody() -> Data? {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = keyEncodingStrategy
        return (try? encoder.encode(self)) ?? "{}".data(using: .utf8)
    }
    
    func multipartBody() -> (data: Data?, requestId: String?) {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = keyEncodingStrategy
        
        guard let bodyData = try? encoder.encode(self),
              var bodyDict = try? JSONSerialization.jsonObject(with: bodyData, options: []) as? [String: Any] else { return (nil, nil) }
        bodyDict.merge(multipart, uniquingKeysWith: { $1 })
        
        var body = Data()
        bodyDict.forEach { key, value in
            body.append("--\(HTTPClient.Constants.boundary)\(HTTPClient.Constants.newline)".data(using: .utf8) ?? Data())
            if let array = value as? [Any] {
                var dataString = ""
                dataString.append("Content-Disposition: form-data; name=\"\(key)\"\(HTTPClient.Constants.newline)\(HTTPClient.Constants.newline)")
                dataString.append("\(array.map { "\($0)".urlEncoded }.joined(separator: ","))")
                
                if let stringData = dataString.data(using: .utf8) {
                    body.append(stringData)
                }
            } else if let binaryData = value as? BinaryData {
                var dataString = ""
                dataString.append("Content-Disposition: form-data; name=\"\(binaryData.name)\"; filename=\"\(binaryData.filename)\"\(HTTPClient.Constants.newline)")
                dataString.append("Content-Type: \(binaryData.type)\(HTTPClient.Constants.newline)")
                dataString.append("Content-Transfer-Encoding: binary")
                dataString.append("\(HTTPClient.Constants.newline)\(HTTPClient.Constants.newline)")
                
                if let stringData = dataString.data(using: .utf8) {
                    body.append(stringData)
                    body.append(binaryData.data)
                }
            } else if let cgSize = value as? CGSize, cgSize != CGSize.zero {
                var dataString = ""
                dataString.append("Content-Disposition: form-data; name=\"\(key)\"\(HTTPClient.Constants.newline)")
                dataString.append("Content-Type: text/plain; charset=utf-8\(HTTPClient.Constants.newline)\(HTTPClient.Constants.newline)")
                dataString.append("\(Int(cgSize.width)),\(Int(cgSize.height))")
                dataString.append(HTTPClient.Constants.newline)
                if let stringData = dataString.data(using: .utf8) {
                    body.append(stringData)
                }
            } else if let value = value as? Bool {
                var dataString = ""
                dataString.append("Content-Disposition: form-data; name=\"\(key)\"\(HTTPClient.Constants.newline)\(HTTPClient.Constants.newline)")
                dataString.append("\(value ? "true" : "false")")
                
                if let stringData = dataString.data(using: .utf8) {
                    body.append(stringData)
                }
            } else if let value = value as? String {
                var dataString = ""
                dataString.append("Content-Disposition: form-data; name=\"\(key)\"\(HTTPClient.Constants.newline)\(HTTPClient.Constants.newline)")
                dataString.append("\(value)")
                
                if let stringData = dataString.data(using: .utf8) {
                    body.append(stringData)
                }
            }
        }
        
        body.append("\(HTTPClient.Constants.newline)--\(HTTPClient.Constants.boundary)--\(HTTPClient.Constants.newline)".data(using: .utf8) ?? Data())
        
        return (body, (bodyDict["request_id"] as? String) ?? (bodyDict["requestId"] as? String))
    }
}
