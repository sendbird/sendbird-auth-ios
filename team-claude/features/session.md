# Feature: 세션 관리 (Session)

> 브랜치 작업 시 참조. 최초 생성: 2026-03-06

## Current Status
- 상태: 활성
- 마지막 작업: 2026-03-06
- 다음 할 일: (작업 시 업데이트)

## Key Directories
- `Sources/SendbirdAuth/Session/` — 세션 키 관리, 토큰 만료 처리
  - `SessionManager.swift` — 핵심 세션 관리 클래스
  - `Session.swift` — 세션 데이터 모델 (암호화/영속화)
  - `InternalSessionDelegate.swift` — 내부 세션 상태 알림 프로토콜
  - `SessionExpirable/SessionExpirable.swift` — 전략 패턴 프로토콜
  - `SessionExpirable/GuestSessionExpirationHandler.swift` — Guest 전략
  - `SessionExpirable/UserSessionExpirationHandler.swift` — User 전략
- 관련 파일:
  - `Common/Commands/Event/SessionExpiredEvent.swift` — EXPR 이벤트
  - `Common/Commands/Event/SessionRefreshedEvent.swift` — 세션 갱신 응답
  - `Common/Commands/Event/LoginEvent.swift` — LOGI 응답
  - `Common/PropertyWrappers/InternalAtomic.swift` — 스레드 안전 프로퍼티 래퍼
  - `Client/RequestQueue.swift` — 세션 검증 후 요청 디스패치
  - `Client/SessionValidator.swift` — 세션 검증 프로토콜

## Architecture

### SessionManager 역할 — 2026-03-06
- **왜**: 세션 키는 연결 전반에 걸쳐 공유되는 민감 상태
- **결정**: `SessionManager`가 세션 키 저장/갱신/검증 전담
- **상태 enum**:
  ```swift
  enum SessionState {
      case connected    // 유효 세션 존재
      case refreshing   // 세션 갱신 중
      case none         // 세션 없음
  }
  ```
- **주요 프로퍼티**:
  - `internalSession: Session?` — `@InternalAtomic` 래핑, UserDefaults 자동 로드
  - `session: Session?` — 공개 getter (자동 동기화), setter (영속화 포함)
  - `eKey: String?` — 암호화 키 (LoginEvent에서 수신)
  - `expirationHandler: SessionExpirable` — Guest/User 만료 처리 전략
  - `authenticateHandlers: [AuthUserHandler?]` — 큐잉된 인증 완료 핸들러
  - `sessionHandler: SessionEventBroadcaster` — 세션 이벤트 멀티캐스트
- **주요 메서드**:
  ```swift
  func authenticate(authData:, loginHandler:)    // 인증 시작
  func connect(authToken:, sessionKey:, loginHandler:)  // 직접 WebSocket 연결
  func reconnect(reconnectedBy:) -> Bool         // 저장된 세션키로 재연결
  func logout()                                  // 세션/상태 클리어
  func validateSession(isSessionRequired:) throws -> String?  // 세션 키 반환 또는 에러
  func validateResponse(_:, error:) -> Bool      // 응답 검증 (만료 시 false)
  ```
- **주의사항**: `@InternalAtomic`으로 스레드 안전 보장. `RequestQueue`가 세션 검증 후 요청 전달

### Session 데이터 모델 — 2026-03-06
- **왜**: 세션 키를 안전하게 영속화하고 서비스 범위(scope)를 관리해야 함
- **결정**: `Session` 구조체 (Codable, Equatable, Comparable)
  ```swift
  struct Session: Codable, Equatable, Comparable {
      let key: String                   // 세션 키
      let services: [Session.Service]   // 서비스 범위
      let isDirty: Bool                 // 캐시에서 로드됨 (fresh 아님)
  }
  enum Service: String, Codable {
      case feed       // value: 1
      case chat       // value: 2
      case chatAPI    // value: 3
  }
  ```
- **영속화**: AES-256 암호화 (userId base64 첫 10자가 키)
- **저장소**: `UserDefaults(suiteName: "com.sendbird.sdk.manager.session")`
- **키**: `"com.sendbird.sdk.messaging.sessionkey"`
- **범위 비교**: `isLargerScope(than:)` — 서비스 int 값 합산 비교 (큰 범위가 우선)

### Session Key + Token Expiration — 2026-03-06
- **왜**: Guest와 User 사용자는 세션 만료 처리 방식이 다름 (Guest는 토큰 갱신 불필요)
- **결정**: 전략 패턴으로 `SessionExpirable` 프로토콜 구현
  ```swift
  protocol SessionExpirable {
      var delegate: InternalSessionDelegate? { get set }
      var isRefreshingSession: Bool { get set }
      func resetSession()
      func refreshSessionKey(shouldRetry:, expiresIn:)
      func refreshSessionToken()
  }
  ```
- **GuestSessionExpirationHandler**:
  - `refreshSessionKey()` → InternalSessionDelegate를 통해 WS 또는 API로 세션 키 갱신
  - `refreshSessionToken()` → **No-op** (Guest는 토큰 없음)
  - 프로퍼티: `expiringSession: Bool`, `accessToken: String?`
- **UserSessionExpirationHandler**:
  - `refreshSessionKey()` → 세션 키 갱신 (세션 델리게이트가 있으면 expiring session 요청)
  - `refreshSessionToken()` → `sessionHandler.didTokenRequire()`로 앱에 새 토큰 요청 → `SBTimer`로 타임아웃 관리 → 토큰 수신 후 `refreshSessionKey()` 호출
  - 프로퍼티: `config: SendbirdConfiguration`, `sessionToken: String?`, `timerBoard: SBTimerBoard`
- **핵심 차이**: Guest는 세션 키만, User는 토큰 + 세션 키 모두 갱신 가능

### 토큰 갱신 플로우 — 2026-03-06
- **왜**: 세션 만료 시 자동 갱신으로 사용자 경험 유지
- **EXPR 이벤트 수신** (WebSocket):
  ```
  { "cmd": "EXPR", "reason": 400309, "expiresIn": 60 }
  ↓
  SessionManager.didReceiveSBCommandEvent(SessionExpiredEvent)
  ↓
  consumeError(event.reason, expiresIn: event.expiresIn)
  ```
- **에러 코드별 처리**:
  | 에러 코드 | 의미 | 처리 |
  |---|---|---|
  | 400302 `accessTokenNotValid` | 토큰 만료 | `refreshSessionToken()` |
  | 400309 `sessionKeyExpired` | 세션 키 만료 | session=nil → `refreshSessionKey(shouldRetry:true)` |
  | 400310 `sessionTokenRevoked` | 토큰 해지 | `sessionHandler.wasClosed()` |
  | 400300 `userDeactivated` | 사용자 비활성화 | `sessionHandler.wasClosed()` |
  | 400301 `userNotExist` | 사용자 없음 | `sessionHandler.wasClosed()` |
- **세션 키 갱신 경로** (WS 우선, API 폴백):
  ```
  InternalSessionDelegate.refreshSessionKey(authToken:, expiringSession:, expiresIn:)
      │
      ├─ WebSocket open && expiresIn >= 5초:
      │    └─ WS LOGIN 시도 (refreshedViaWS = true)
      │         실패 시 → API 폴백
      │
      └─ 그 외:
           └─ API POST /v3/users/{userId}/session_key (refreshedViaWS = false)

  완료: (refreshedViaWS, sessionKey, error)
      ├─ 성공: didSessionKeyRefresh(key:, requireReconnect: !refreshedViaWS)
      │    ├─ API로 갱신 → reconnect 필요 (sessionReconnectRequired)
      │    └─ WS로 갱신 → Connected 상태 유지
      └─ 실패: didSessionKeyFailToRefresh(error:) → 세션 nil 처리
  ```
- **토큰 갱신 플로우** (User만):
  ```
  1. refreshSessionToken() 호출
  2. SBTimer 생성 (sessionTokenRefreshTimeoutSec, 예: 30초)
  3. sessionHandler.didTokenRequire() → 모든 AuthSessionDelegate에 브로드캐스트
  4. 앱에서 새 토큰 또는 실패 응답
  5. 성공: sessionToken 업데이트 → refreshSessionKey(shouldRetry: false)
  6. 타임아웃/실패: didSessionTokenFailToRefresh()
  ```

### LOGI 커맨드 처리 — 2026-03-06
- **LoginEvent 구조**:
  ```swift
  struct LoginEvent: SBCommand {
      var sessionKey: String?           // 세션 키
      var eKey: String?                 // 암호화 키
      var services: [Session.Service]?  // 범위: [.feed, .chat, .chatAPI]
      var expiresAt: Int64?            // 만료 타임스탬프 (초)
      var user: AuthUser?
      var appInfo: AuthAppInfo?
  }
  ```
- **세션 생성**: `Session(key: sessionKey, services: services)` → UserDefaults 자동 영속화
- **전송 시점**: 최초 인증 (AuthenticateRequest), WS LOGIN (세션 갱신), API POST (세션 갱신)

### RequestQueue 세션 검증 — 2026-03-06
- **왜**: 모든 요청은 유효한 세션에서만 전송되어야 함
- **API 요청 프로세스 전략** (`apiProcessStrategy`):
  | SessionState | ConnectionState | 결과 |
  |---|---|---|
  | `.connected` | Connecting | `.onHold` (대기) |
  | `.connected` | 그 외 | `.process` (전송) |
  | `.refreshing` | — | `.onHold` (대기) |
  | `.none` | — | `.error(connectionRequired)` |
- **WS 요청 프로세스 전략** (`wsProcessStrategy`):
  | SessionState | 소켓 상태 | 결과 |
  |---|---|---|
  | `.connected` | open | `.process` |
  | `.connected` | closed | `.error(webSocketConnectionClosed)` |
  | `.refreshing` + LOGIN 커맨드 | open | `.process` (예외: 갱신 중에도 LOGIN 허용) |
  | `.refreshing` | — | `.onHold` |
  | `.none` | — | `.error(connectionRequired)` |
- **큐잉된 요청 처리**: 세션 갱신 완료 (`SessionRefreshed`, `SessionExpirationEvent.Refreshed`) 시 대기 요청 재처리
- **자동 재시도**: `validateResponse()` false 반환 시 요청 자동 재전송

### @InternalAtomic 프로퍼티 래퍼 — 2026-03-06
- **왜**: 다중 스레드에서 세션 상태의 안전한 접근 필요
- **구현**:
  ```swift
  @propertyWrapper class InternalAtomic<T> {
      private var internalValue: T
      private let lock: DispatchQueue  // 전용 직렬 큐

      var wrappedValue: T {
          get { lock.sync { internalValue } }        // 동기 읽기
          set { lock.sync { self.internalValue = newValue } }  // 동기 쓰기
      }
      func atomicMutate(_ mutation: (inout T) -> Void) {
          lock.sync { mutation(&internalValue) }     // 원자적 변경
      }
  }
  ```
- **사용처**: `SessionManager.internalSession`, `SessionManager.eKey`, `SessionManager.authenticateHandlers`, `RequestQueue.router`, `RequestQueue.connectionState`

### InternalSessionDelegate — 2026-03-06
- **왜**: SessionManager ↔ expirationHandler 간의 세션 상태 변경 알림 인터페이스
- **프로토콜**:
  ```swift
  protocol InternalSessionDelegate: AnyObject {
      func didSessionTokenFailToRefresh(error: AuthClientError)
      func didSessionKeyFailToRefresh(error: AuthClientError)
      func didSessionKeyRefresh(key: Session, requireReconnect: Bool)
      func didSessionTokenRevoke()
      func refreshSessionKey(authToken:, expiringSession:, expiresIn:, completionHandler:)
  }
  ```

### EventDelegate 통합 — 2026-03-06
- **SessionManager** (`priority: .highest`):
  - `SessionRefreshedEvent` → 세션 키 업데이트
  - `SessionExpiredEvent` → `consumeError()` 호출
  - `ConnectionStateEvent.Connected` → LoginEvent에서 세션 생성
  - `ConnectionStateEvent.Logout` → `logout()` 호출
- **RequestQueue**:
  - `SessionRefreshed` / `SessionExpirationEvent.Refreshed` → 대기 요청 재처리
  - `SessionExpirationEvent.RefreshFailed` → 에러와 함께 요청 처리
  - `InternalDisconnected` / `ExternalDisconnected` / `Logout` → 큐 클리어

## Learnings
> (작업 중 새로 알게 된 것을 날짜와 함께 기록)

## Known Issues
> (미해결 이슈)

## Solved Problems
> (해결된 문제 이력)

## Dependencies
- 의존: Client (`CommandRouter` — WebSocket/API 요청), Common/Commands (`SessionExpiredEvent`, `SessionRefreshedEvent`, `LoginEvent`), Common/PropertyWrappers (`InternalAtomic`)
- 피의존: Connection (세션 만료 시 재연결 트리거, `sessionReconnectRequired`), RequestQueue (세션 검증 — `SessionValidator`), Stats (세션 이벤트 수집)
