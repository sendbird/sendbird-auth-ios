//
//  File+SendbirdChat.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/19.
//
// swiftlint:disable identifier_name
// swiftlint:disable duplicate_conditions

import Foundation
#if os(iOS)
import MobileCoreServices
#else
import CoreServices
#endif

@_spi(SendbirdInternal) public extension String {
    func inferMimeType(with file: Data?) -> String? {
        guard file != nil else { return nil }
        
        guard let ext = self.pathExtension,
              ext.isEmpty == false else {
            return file?.inferMimeType()
        }
        
        guard let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, ext as CFString, nil)?.takeRetainedValue() else { return nil }
        let mimeType = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)
        return mimeType?.takeRetainedValue() as String?
    }
}

@_spi(SendbirdInternal) public extension Data {
    func inferMimeType() -> String {
        var c = [UInt8](repeating: 0, count: self.count)
        
        if count >= 2 {
            copyBytes(to: &c, count: 2)
            
            if c[0] == 0x42, c[1] == 0x4D {
                // BMP(Bitmap image): 42 4D
                return "image/bmp"
            }
            
            if c[0] == 0xFF, c[1] == 0xFB {
                // MP3(MP3 audio file): FF FB
                return "audio/mp3"
            }
            
            if c[0] == 0xFF, c[1] == 0xFA {
                // MP3(MP3 audio file): FF FB
                return "audio/mp3"
            }
        }
        
        if count >= 3 {
            copyBytes(to: &c, count: 3)
            
            if c[0] == 0x49, c[1] == 0x44, c[2] == 0x33 {
                // MP3(MP3 audio file): 49 44 33
                return "audio/mp3"
            } else if c[0] == 0x49, c[1] == 0x20, c[2] == 0x49 {
                // TIF(TIFF file_1): 49 20 49
                return "image/tiff"
            }
        }
        
        if count >= 4 {
            copyBytes(to: &c, count: 4)
            
            if c[0] == 0x47, c[1] == 0x49, c[2] == 0x46, c[3] == 0x38 {
                // GIF(GIF file): 47 49 46 38
                return "image/gif"
            } else if c[0] == 0xFF, c[1] == 0xD8, c[2] == 0xFF, c[3] == 0xE0 {
                // JPEG(JPEG IMAGE): FF D8 FF E0
                return "image/jpeg"
            } else if c[0] == 0xFF, c[1] == 0xD8, c[2] == 0xFF, c[3] == 0xE2 {
                // JPEG(CANNON EOS JPEG FILE): FF D8 FF E2
                return "image/jpeg"
            } else if c[0] == 0xFF, c[1] == 0xD8, c[2] == 0xFF, c[3] == 0xE3 {
                // JPEG(SAMSUNG D500 JPEG FILE): FF D8 FF E3
                return "image/jpeg"
            } else if c[0] == 0xFF, c[1] == 0xD8, c[2] == 0xFF, c[3] == 0xE1 {
                // JPG(Digital camera JPG using Exchangeable Image File Format (EXIF)): FF D8 FF E1
                return "image/jpeg"
            } else if c[0] == 0xFF, c[1] == 0xD8, c[2] == 0xFF, c[3] == 0xE8 {
                // JPG(Still Picture Interchange File Format (SPIFF)): FF D8 FF E8
                return "image/jpeg"
            } else if c[0] == 0x6D, c[1] == 0x6F, c[2] == 0x6F, c[3] == 0x76 {
                // MOV(QuickTime movie_1): 6D 6F 6F 76
                return "video/quicktime"
            } else if c[0] == 0x66, c[1] == 0x72, c[2] == 0x65, c[3] == 0x65 {
                // MOV(QuickTime movie_2): 66 72 65 65
                return "video/quicktime"
            } else if c[0] == 0x6D, c[1] == 0x64, c[2] == 0x61, c[3] == 0x74 {
                // MOV(QuickTime movie_3): 6D 64 61 74
                return "video/quicktime"
            } else if c[0] == 0x77, c[1] == 0x69, c[2] == 0x64, c[3] == 0x65 {
                // MOV(QuickTime movie_4): 77 69 64 65
                return "video/quicktime"
            } else if c[0] == 0x70, c[1] == 0x6E, c[2] == 0x6F, c[3] == 0x74 {
                // MOV(QuickTime movie_5): 70 6E 6F 74
                return "video/quicktime"
            } else if c[0] == 0x73, c[1] == 0x6B, c[2] == 0x69, c[3] == 0x70 {
                // MOV(QuickTime movie_6): 73 6B 69 70
                return "video/quicktime"
            } else if c[0] == 0x00, c[1] == 0x00, c[2] == 0x01, c[3] == 0xBA {
                // MPG(DVD video file): 00 00 01 BA
                return "video/mpeg"
            } else if c[0] == 0x00, c[1] == 0x00, c[2] == 0x01, c[3] == 0xB3 {
                // MPG(MPEG video file): 00 00 01 B3
                return "video/mpeg"
            } else if c[0] == 0x49, c[1] == 0x49, c[2] == 0x2A, c[3] == 0x00 {
                // TIF(TIFF file_2): 49 49 2A 00
                return "image/tiff"
            } else if c[0] == 0x4D, c[1] == 0x4D, c[2] == 0x00, c[3] == 0x2A {
                // TIF(TIFF file_3): 4D 4D 00 2A
                return "image/tiff"
            } else if c[0] == 0x4D, c[1] == 0x4D, c[2] == 0x00, c[3] == 0x2B {
                // TIF(TIFF file_4): 4D 4D 00 2B
                return "image/tiff"
            }
        }
        
        if count >= 5 {
            copyBytes(to: &c, count: 5)
            
            if c[0] == 0x46, c[1] == 0x4F, c[2] == 0x52, c[3] == 0x4D, c[4] == 0x00 {
                // AIFF(Audio Interchange File): 46 4F 52 4D 00
                return "audio/aiff"
            }
        }
        
        if count >= 8 {
            copyBytes(to: &c, count: 8)
            
            if c[0] == 0x00, c[1] == 0x00, c[2] == 0x00, c[3] == 0x14, c[4] == 0x66, c[5] == 0x74, c[6] == 0x79, c[7] == 0x70 {
                // 3GP(3GPP multimedia files): 00 00 00 14 66 74 79 70
                return "video/3gpp"
            } else if c[0] == 0x00, c[1] == 0x00, c[2] == 0x00, c[3] == 0x14, c[4] == 0x66, c[5] == 0x74, c[6] == 0x79, c[7] == 0x70 {
                // MOV(Quicktime multimedia files): 00 00 00 14 66 74 79 70
                return "video/quicktime"
            } else if c[0] == 0x00, c[1] == 0x00, c[2] == 0x00, c[3] == 0x20, c[4] == 0x66, c[5] == 0x74, c[6] == 0x79, c[7] == 0x70 {
                // 3GP2(3GPP2 multimedia files): 00 00 00 20 66 74 79 70
                return "video/3gpp2"
            } else if c[0] == 0x30, c[1] == 0x26, c[2] == 0xB2, c[3] == 0x75, c[4] == 0x8E, c[5] == 0x66, c[6] == 0xCF, c[7] == 0x11 {
                // ASF(Windows Media Audio|Video File): 30 26 B2 75 8E 66 CF 11
                return "video/asf"
            } else if c[0] == 0x00, c[1] == 0x00, c[2] == 0x00, c[3] == 0x0C, c[4] == 0x6A, c[5] == 0x50, c[6] == 0x20, c[7] == 0x20 {
                // JP2(JPEG2000 image files): 00 00 00 0C 6A 50 20 20
                return "image/jp2"
            } else if c[0] == 0x4F, c[1] == 0x67, c[2] == 0x67, c[3] == 0x53, c[4] == 0x00, c[5] == 0x02, c[6] == 0x00, c[7] == 0x00 {
                // OGG(Ogg Vorbis Codec compressed file): 4F 67 67 53 00 02 00 00
                return "audio/ogg"
            } else if c[0] == 0x89, c[1] == 0x50, c[2] == 0x4E, c[3] == 0x47, c[4] == 0x0D, c[5] == 0x0A, c[6] == 0x1A, c[7] == 0x0A {
                // PNG(PNG image): 89 50 4E 47 0D 0A 1A 0A
                return "image/png"
            } else if c[0] == 0x30, c[1] == 0x26, c[2] == 0xB2, c[3] == 0x75, c[4] == 0x8E, c[5] == 0x66, c[6] == 0xCF, c[7] == 0x11 {
                // WMA(Windows Media Audio|Video File): 30 26 B2 75 8E 66 CF 11
                return "audio/x-ms-wma"
            } else if c[0] == 0x30, c[1] == 0x26, c[2] == 0xB2, c[3] == 0x75, c[4] == 0x8E, c[5] == 0x66, c[6] == 0xCF, c[7] == 0x11 {
                // WMV(Windows Media Audio|Video File): 30 26 B2 75 8E 66 CF 11
                return "video/x-ms-wmv"
            } else if c[4] == 0x6D, c[5] == 0x6F, c[6] == 0x6F, c[7] == 0x76 {
                // MOV(Quicktime multimedia files): XX XX XX XX 6D 6F 6F 76
                return "video/quicktime"
            }
        }
        
        if count >= 11 {
            copyBytes(to: &c, count: 11)
            
            if c[4] == 0x66, c[5] == 0x74, c[6] == 0x79, c[7] == 0x70, c[8] == 0x6D, c[9] == 0x70, c[10] == 0x34 {
                // M4A(Apple audio and video files): 00 00 00 18 66 74 79 70 6D 70 34
                return "video/mp4"
            } else if c[4] == 0x66, c[5] == 0x74, c[6] == 0x79, c[7] == 0x70, c[8] == 0x33, c[9] == 0x67, c[10] == 0x70 {
                // M4A(Apple audio and video files): 00 00 00 14 66 74 79 70 33 67 70
                return "video/3gp"
            }
        }
        
        return "application/octet-stream"
    }
}

@_spi(SendbirdInternal) public extension URL {
    func inferMimeType() -> String? {
        guard let uti = UTTypeCreatePreferredIdentifierForTag(
                kUTTagClassFilenameExtension, pathExtension as CFString, nil
        )?.takeRetainedValue() else {
            return nil
        }
        
        let mimeType = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)
        return mimeType?.takeRetainedValue() as String?
    }
}

// swiftlint:enable identifier_name
// swiftlint:enable duplicate_conditions
