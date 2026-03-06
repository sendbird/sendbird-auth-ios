# Feature: HTTP/WebSocket 클라이언트 (Client)

> 브랜치 작업 시 참조. 최초 생성: 2026-03-06

## Current Status
- 상태: 활성
- 마지막 작업: 2026-03-06
- 다음 할 일: (작업 시 업데이트)

## Key Directories
- `Sources/SendbirdAuth/Client/` — 네트워크 전송 레이어
  - `CommandRouter.swift` — 중앙 오케스트레이터 (HTTP/WS 라우팅, `SocketSendActor`/`SocketReceiveActor` 관리)
  - `RequestQueue.swift` — 세션 검증 + 요청 큐잉 + 타임아웃 관리
  - `SessionValidator.swift` — 세션 상태 검증 프로토콜
  - `AckTimerManager.swift` — WS ACK 타임아웃 관리 actor (1:N requestId→context 매핑)
  - `CommandRouterConfiguration.swift` — API/WS 호스트, 캐시 정책 설정
  - `RequestHeadersBuilder.swift` — HTTP 요청 헤더 빌더 패턴
  - `RequestHeadersContext.swift` — 디바이스/SDK/앱 메타데이터 (불변)
  - `RequestHeaderDataSource.swift` — 요청 헤더 제공 프로토콜
  - `WebSocketStatEvent.swift` — WS 생명주기 텔레메트리 이벤트
  - `HTTP/` — URLSession 기반 HTTP 클라이언트
    - `HTTPClient.swift` — 요청/응답, 멀티파트 업로드, 백그라운드 전송
    - `DummyRequest.swift` — TLS 핸드셰이크 프리페칭용 빈 GET 요청
  - `Websocket/` — WebSocket 클라이언트
    - `ChatWebSocketClient.swift` — Actor. 핑/워치독 타이머, 메시지 버퍼링, 이벤트 브로드캐스팅
    - `SessionWebSocketEngine.swift` — URLSessionWebSocketTask 기반 구체 엔진 (NWPathMonitor 네트워크 모니터링)
    - `Event/WebSocketEngineEvent.swift` — 저수준 엔진 이벤트
    - `Event/WebSocketClientEvent.swift` — 고수준 클라이언트 이벤트
    - `Protocol/ChatWebSocketEngine.swift` — WS 엔진 프로토콜
    - `Protocol/ChatWebSocketClientInterface.swift` — WS 클라이언트 공개 API
  - `Websocket/RequestBucket/` — 요청 배치 처리
    - `BatchedRequestBucket.swift` — 커맨드 타입별 배치 관리 actor
    - `Bucketable.swift` — 배치 가능 커맨드 프로토콜 (`copy(newId:)`)
    - `Sender/WebSocketRequestSendable.swift` — 전송 가능 요청 프로토콜
    - `Sender/ZeroGapRequestSender.swift` — 즉시 전송
    - `Sender/DebouncedRequestSender.swift` — 디바운스 전송 (기본 0.5초)

## Architecture

### HTTP + WebSocket 이중 전송 레이어 — 2026-03-06
- **왜**: 인증 API는 HTTP REST, 실시간 이벤트는 WebSocket으로 분리됨
- **결정**: `CommandRouter`가 커맨드 타입에 따라 HTTP 또는 WS 경로로 라우팅
- **요청 파이프라인**:
  ```
  Caller → RequestQueue (세션 검증 + 큐잉 + 타임아웃)
             → CommandRouter
                ├── HTTP: apiOperationQueue (maxConcurrent=1) → HTTPClient → URLSession
                └── WS:  @SocketSendActor → BatchedRequestBucket? → WebSocketManager → ChatWebSocketClient
  ```
- **주의사항**: HTTP는 `OperationQueue` (maxConcurrent=1)로 직렬화, WS 송신은 `@globalActor SocketSendActor`로 직렬화

### CommandRouter 상세 — 2026-03-06
- **왜**: HTTP와 WS 요청을 통합 관리하는 중앙 점이 필요
- **결정**: `CommandRouter`가 요청 라우팅, ACK 관리, 배치 처리, 메시지 수신 파싱 담당
- **Global Actor 분리**:
  ```swift
  @globalActor actor SocketSendActor { static let shared = SocketSendActor() }
  @globalActor actor SocketReceiveActor { static let shared = SocketReceiveActor() }
  ```
  - 송신(ACK 포함)과 수신(이벤트)이 간섭하지 않음
- **API 요청 라우팅**:
  1. `apiOperationQueue` 진입 (직렬화)
  2. WS 이벤트 중복제거 규칙 등록
  3. Session-Key 헤더 추가
  4. 멀티파트 → 백그라운드 URLSession, 일반 → 기본 URLSession
- **WS 요청 라우팅**:
  1. `markAsReadBucket` 배치 대상인지 확인 (`.read` 커맨드)
  2. 배치 대상 → bucket.hold() (ACK 수신 시 플러시)
  3. 일반 → `webSocketManager.sendWS()` 즉시 전송
- **메시지 수신 처리**:
  ```swift
  didReceiveMessage(message: String) {
      // 1. 외부 파싱 전략 실행 (브로드캐스트)
      // 2. 메인 파싱 전략으로 커맨드 파싱
      // 3. ACK → @SocketSendActor에서 처리
      //    이벤트 → @SocketReceiveActor에서 처리
  }
  ```

### HTTPClient 상세 — 2026-03-06
- **왜**: URLSession 기반의 안전한 HTTP 통신 레이어 필요
- **결정**: `HTTPClient` 클래스 (NSObject, URLSessionDelegate)
- **URLSession 설정**:
  - 기본: ephemeral, 캐시 없음 (`reloadIgnoringCacheData`)
  - 백그라운드: `background(withIdentifier:)` 앱 확장 지원 (`sharedContainerIdentifier`)
- **요청/응답 처리**:
  - 헤더: Accept, Connection, Request-Sent-Timestamp, 커스텀 헤더
  - 전체 요청/응답 로깅
  - 지연시간 텔레메트리 (`APIResultStat`)
  - 디코딩: `SendbirdAuth.authDecoder`
- **멀티파트 업로드**:
  - 바운더리: `uwhQ9Ho7y873Ha`
  - 임시 파일에 body 기록 → URLSessionUploadTask
  - `URLBackgroundTask` 래핑으로 생명주기 관리
  - 전송 타임아웃: 60초 (설정 가능)
- **SafeCancellableDataTask**: 스레드 안전 취소 래퍼
  ```swift
  class URLSessionSafeCancellableDataTask {
      private let lock = NSLock()
      private var state: State = .created  // created → running → cancelled/completed
  }
  ```
- **에러 매핑**:
  | 소스 | 에러 |
  |---|---|
  | 네트워크 오류 | `AuthCoreError.networkError` |
  | 취소 | `AuthCoreError.requestFailed` |
  | 응답 파싱 실패 | `AuthCoreError.malformedData` |
  | 4xx | JSON 본문에서 디코딩 |
  | 5xx+ | `AuthCoreError.internalServerError` |
- **DummyRequest**: TLS 핸드셰이크 프리페칭용 빈 GET 요청 (연결 지연 감소)

### ChatWebSocketClient (Actor) — 2026-03-06
- **왜**: WebSocket 연결의 고수준 관리 (타이머, 버퍼링, 이벤트 전달) 필요
- **결정**: Actor 기반 클라이언트
- **Ping/Watchdog 메커니즘**:
  - Ping 타이머: 1초마다 체크, 마지막 활동 이후 `pingInterval` (기본 15초) 경과 시 ping 전송
  - Watchdog 타이머: ping 전송 후 시작, `watchdogInterval` (기본 5초) 내 pong 미수신 시 연결 종료
  - 활동 추적: 송수신 성공 시 업데이트
- **메시지 버퍼링**: 개행(`\n`) 구분 메시지 점진적 파싱
  ```swift
  recvBuffer.append(message)
  while let newlineIndex = recvBuffer.firstIndex(of: "\n") {
      let line = String(recvBuffer[..<newlineIndex])
      // CRLF 트림 후 이벤트 브로드캐스트
  }
  ```

### SessionWebSocketEngine (Actor) — 2026-03-06
- **왜**: 실제 URLSessionWebSocketTask 관리 + 네트워크 상태 감시
- **결정**: Actor 기반 엔진 (NWPathMonitor 통합)
- **상태 머신**: `.closed` → `.connecting` → `.open` → `.closed`
- **TLS**: `TLSv13` 최대 지원
- **네트워크 모니터링**: `NWPathMonitor`로 네트워크 불가 감지 → `.connectionFailed` 이벤트
- **메시지 루프**:
  ```swift
  while !Task.isCancelled {
      let message = try await task.receive()
      guard self.websocketTask === task else { break }  // stale task 방지
      await eventBroadcaster.yield(.received(message))
  }
  ```

### WebSocket 엔진 주입 — 2026-03-06
- **왜**: 테스트 시 실제 WebSocket 연결 없이 엔진 교체 필요
- **결정**: `ChatWebSocketEngine` actor 프로토콜 + `injectEngineForTest()` 메서드로 테스트용 주입 지원
- **주의사항**: 프로덕션에서는 기본 엔진 사용. 테스트 외 주입 금지

### AckTimerManager — 2026-03-06
- **왜**: WS 요청에 대한 ACK 응답 타임아웃 관리 필요
- **결정**: Actor 기반, 1:N requestId→AckContext 매핑
  ```swift
  actor AckTimerManager {
      struct AckContext {
          let timer: AsyncTimer
          let request: AnyResultable
          let handler: Any?
      }
      var contexts: [String: [AckContext]] = [:]
  }
  ```
- **등록**: `register(request:, completionHandler:, timeout:)` → AsyncTimer 시작
- **응답 처리**: `handleResponse(command:)` → requestId로 매칭, 타이머 취소, 핸들러 호출
- **타임아웃**: 로그 경고 + `AuthClientError.ackTimeout` 에러 핸들러 호출

### Request Bucket (배치 요청) — 2026-03-06
- **왜**: 동일 유형 요청을 개별 전송하면 WS 트래픽 낭비 (특히 `.read` mark-as-read)
- **결정**: `BatchedRequestBucket` actor로 요청 배치 처리
- **Hold/Flush 로직**:
  ```
  1. hold(request) → flush 대기 → requestIdStack에 추가 → 전략에 따라 fire
  2. shouldFlush(command) → ACK 수신 시 requestIdStack에 reqId 포함되면 true
  3. flushPendingRequests(command) → 스택의 모든 requestId에 대해 command.copy(newId:) → 핸들러 호출
  ```
- **전송 전략**:
  | 전략 | 동작 |
  |---|---|
  | `ZeroGapRequestSender` | 즉시 전송 (지연 없음) |
  | `DebouncedRequestSender` | 0.5초 디바운스, 새 요청 도착 시 이전 취소 (last-write-wins) |

### RequestQueue 상세 — 2026-03-06
- **왜**: 세션 검증, 요청 큐잉, 타임아웃을 통합 관리
- **결정**: `RequestQueue` 클래스가 CommandRouter를 래핑
- **큐잉 메커니즘**:
  ```swift
  send(request:) {
      let completionGuard = CompletionGuard()  // 이중 완료 방지
      let timer = SBTimer(timeout) { ... }     // 요청 타임아웃

      let queueItem = {
          switch processStrategy(request) {
          case .onHold: return .onHold   // 재큐잉
          case .error:  return .error    // 에러 즉시 반환
          case .process:                 // 세션 검증 후 전송
              let sessionKey = validateSession()
              router.send(request, sessionKey)
          }
      }
      queuedRequests.append(queueItem)
      processQueuedRequests()
  }
  ```
- **HTTP 편의 메서드**: GET, POST, PUT, PATCH, DELETE
  - `path: URLPathConvertible`
  - `body`, `additionalBody`: Encodable
  - `multipart`: [String: Any]
  - `isSessionRequired`, `isLoginRequired`: Bool
  - `sendImmediately`: 큐 바이패스
  - `wsEventDeduplicationRules`: 서버 이벤트 필터

### SafeContinuation — 2026-03-06
- **왜**: CheckedContinuation의 이중 resume 크래시 방지
- **결정**: `SafeThrowingContinuation<T>` 래퍼 + `CompletionGuard`
  ```swift
  class SafeThrowingContinuation<T> {
      private let continuation: CheckedContinuation<T, Error>
      private let completionGuard: CompletionGuard

      func resume(returning value: T) {
          completionGuard.finishOnce {
              continuation.resume(returning: value)
          }
      }
  }

  class CompletionGuard {
      private var _hasCompleted = false
      private let lock = NSLock()

      func finishOnce(_ handler: () -> Void) {
          lock.lock()
          guard !_hasCompleted else { lock.unlock(); return }
          _hasCompleted = true
          lock.unlock()
          handler()
      }
  }
  ```
- **사용**: `try await withSafeThrowingContinuation { continuation in ... }`
- **시나리오**: 타임아웃과 API 콜백이 동시에 경합하는 경우

### 커맨드 타입 — 2026-03-06
- **주요 CommandType** (String RawValue):
  | 타입 | 값 | 설명 | ACK 필요 |
  |---|---|---|---|
  | `.login` | `"LOGI"` | 로그인 | O |
  | `.userMessage` | `"MESG"` | 사용자 메시지 | O |
  | `.fileMessage` | `"FILE"` | 파일 메시지 | O |
  | `.adminMessage` | `"ADMM"` | 관리자 메시지 | X |
  | `.read` | `"READ"` | 읽음 표시 (배치됨) | O |
  | `.delivery` | `"DLVR"` | 수신 확인 | X |
  | `.reaction` | `"MRCT"` | 리액션 | X |
  | `.ping` | `"PING"` | 핑 | X |
  | `.pong` | `"PONG"` | 퐁 | X |
  | `.sessionExpired` | `"EXPR"` | 세션 만료 | X |
  | `.busy` | `"BUSY"` | 서버 과부하 (4.34.0) | X |
  | `.error` | `"EROR"` | 에러 | X |

### 에러 타입 — 2026-03-06
- **AuthClientError** (SDK 레벨):
  | 코드 | 이름 | 설명 |
  |---|---|---|
  | 800101 | `connectionRequired` | 연결 필요 |
  | 800102 | `connectionCanceled` | 연결 취소됨 |
  | 800120 | `networkError` | 네트워크 오류 |
  | 800130 | `malformedData` | 응답 파싱 실패 |
  | 800180 | `ackTimeout` | ACK 타임아웃 |
  | 800190 | `loginTimeout` | 로그인 타임아웃 |
  | 800191 | `reconnectLoginTimeout` | 재연결 로그인 타임아웃 |
  | 800200 | `webSocketConnectionClosed` | WS 닫힘 |
  | 800210 | `webSocketConnectionFailed` | WS 실패 |
  | 800220 | `requestFailed` | 요청 실패 |
  | 800240 | `fileUploadCanceled` | 업로드 취소 |
  | 800250 | `fileUploadTimeout` | 업로드 타임아웃 |
  | 500901 | `internalServerError` | 서버 내부 오류 |

### 테스트 지원 — 2026-03-06
- **DI**: 모든 컴포넌트가 `Injectable` 프로토콜 사용
- **프로토콜 기반**: `HTTPClientInterface`, `ChatWebSocketEngine`, `ChatWebSocketClientInterface`
- **#if DEBUG 메서드**: `getRequestHeaderContext()`, `getWebsocketClient()`, `simulateDidReceiveMessage()`
- **RequestQueue**: `sendWSInterception` 클로저로 WS 전송 인터셉트 가능

## Learnings
> (작업 중 새로 알게 된 것을 날짜와 함께 기록)

## Known Issues
> (미해결 이슈)

## Solved Problems
> (해결된 문제 이력)

## Dependencies
- 의존: Common/Commands (커맨드 타입 계층), Common/Concurrency (`SafeSerialQueue`, `SafeContinuation`)
- 피의존: Connection (WS 이벤트 수신, 상태 전환), Session (세션 키 제공, `SessionValidator`), Stats (HTTP 요청 전송, API 지연시간 수집)
