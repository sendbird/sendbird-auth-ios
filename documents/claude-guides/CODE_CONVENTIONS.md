# auth-ios (SendbirdAuthSDK) Code Conventions

> Claude Code 작업 시 참고용 코드 컨벤션 문서. 코드 작성/수정 시 이 문서의 규칙을 따를 것.
> 마지막 업데이트: 2026-03-03

---

## 1. 프로젝트 개요

- **모듈명**: `SendbirdAuthSDK` (단일 Swift 모듈)
- **경로**: `Sources/SendbirdAuth/`
- **현재 버전**: `0.0.11` (`SendbirdAuth.swift`)
- **최소 지원**: iOS 13+, macOS 11+, Swift 5.9
- **빌드 시스템**: SPM (`Package.swift`) + XcodeGen (`project.yml`)
- **외부 의존성**: 없음 (Apple 프레임워크만 사용)
- **공개 API**: `@_spi(SendbirdInternal)` — 다른 Sendbird SDK 전용, 외부 사용자 비공개

---

## 2. 프로젝트 구조

```
Sources/SendbirdAuth/
├── SendbirdAuth.swift          # 싱글톤 파사드
├── SendbirdAuthMain.swift      # Composition root (모든 서브시스템 생성/연결)
├── Configuration.swift         # Host URL 해석
├── Client/                     # 네트워크 전송 (HTTP, WebSocket, CommandRouter)
│   ├── HTTP/                   # URLSession 기반 HTTP 클라이언트
│   └── Websocket/              # WebSocket 클라이언트, 엔진, 요청 버킷
├── Connection/                 # WebSocket 상태 머신 + 델리게이트 + 브로드캐스터
│   ├── State/                  # 9개 연결 상태 (State 패턴)
│   ├── Delegates/              # AuthConnectionDelegate, AuthSessionDelegate
│   ├── Broadcaster/            # 이벤트 멀티캐스트
│   └── Manager/                # DeviceConnectionManager
├── Session/                    # 세션 키 관리, 토큰 만료 처리
│   └── SessionExpirable/       # 전략 패턴 (Guest/User)
├── Stats/                      # 텔레메트리 수집/전송
├── Logger/                     # 카테고리 기반 구조화 로거
├── Timer/                      # RunLoop/Concurrency 기반 타이머
├── User/                       # AuthUser 모델
├── Operation/                  # SafeSerialQueue
└── Common/
    ├── Commands/               # Command/Request/Response/Event 타입 계층
    │   ├── Base/               # 기본 프로토콜 (Command, Request, Response)
    │   ├── Event/              # WS 이벤트 (LOGI, EXPR, SESS, BUSY)
    │   ├── Internal/           # 내부 상태 이벤트
    │   └── User/Auth/          # 인증 요청
    ├── Concurrency/            # AsyncStream, AsyncTimer, SafeContinuation
    ├── Dependency/             # DI 프로토콜 + Property Wrapper
    ├── Model/                  # Codable 값 타입
    │   ├── Auth/               # AuthData, InternalAuthTokenType
    │   ├── Error/              # AuthError, AuthClientError, ErrorMessage
    │   ├── Stats/              # 통계 모델
    │   └── Types/              # 핸들러 타입, 채널 타입, 연결 상태
    ├── PropertyWrappers/       # @InternalAtomic, @UserDefault 등
    ├── Data Structure/         # SafeDictionary, OrderedSet, Queue
    ├── Extension/              # Foundation 타입 확장
    └── Misc/                   # WS 이벤트 중복 제거
```

---

## 3. 네이밍 컨벤션

### 3.1 타입 이름

| 종류 | 규칙 | 예시 |
|------|------|------|
| **Class** | PascalCase. Public/SPI 노출 시 `Auth` 접두사 | `AuthUser`, `AuthError` |
| **Class (내부)** | PascalCase. `Auth` 접두사 없음 | `WebSocketManager`, `SessionManager`, `CommandRouter` |
| **Struct** | PascalCase. 값 타입 모델/이벤트/네임스페이스 | `LoginEvent`, `SendbirdSDKInfo`, `DelegateKeys` |
| **Enum** | PascalCase 이름, lowerCamelCase 케이스 | `AuthClientError.connectionRequired` |
| **Protocol** | PascalCase. `-able`, `-DataSource`, `-Delegate` 접미사 | `ConnectionStatable`, `WebSocketDataSource`, `AuthSessionDelegate` |
| **Typealias** | PascalCase | `AuthUserHandler`, `VoidHandler`, `ConnectionContext` |

### 3.2 멤버 이름

| 종류 | 규칙 | 예시 |
|------|------|------|
| **함수** | lowerCamelCase. 동사로 시작 | `connect()`, `disconnect()`, `resolve(with:)` |
| **변수/프로퍼티** | lowerCamelCase | `applicationId`, `sessionKey`, `webSocketClient` |
| **Boolean** | `is`/`has`/`should` 접두사 | `isConnected`, `hasError`, `shouldRevokeSession` |
| **상수** | `static let` in `Constants` struct. lowerCamelCase | `Constants.defaultDedupIntervalMs` |

### 3.3 파일 이름

| 패턴 | 규칙 | 예시 |
|------|------|------|
| **주요 타입** | `TypeName.swift` | `AuthUser.swift`, `Logger.swift` |
| **확장 (Foundation)** | `BaseType+SendBirdSDK.swift` | `String+SendBirdSDK.swift`, `Codable+SendBirdSDK.swift` |
| **확장 (최신)** | `BaseType+Sendbird.swift` | `Result+Sendbird.swift` |
| **중첩 타입** | `Parent.Child.swift` | `Logger.Descriptor.swift`, `Logger.Observer.swift` |
| **프로토콜** | `ProtocolName.swift` | `ConnectionStatable.swift`, `Injectable.swift` |

---

## 4. 접근 제어 (Access Control)

### 4.1 기본 원칙

```swift
// 다른 Sendbird SDK에 노출 (가장 일반적)
@_spi(SendbirdInternal) public class AuthUser { ... }
@_spi(SendbirdInternal) public var userId: String

// 진정한 public (극히 드문 케이스 — NSCopying 등)
public extension String { ... }
open func copy(with zone: NSZone?) -> Any

// 모듈 내부 전용 (implicit internal)
class WebSocketManager { ... }
var state: ConnectionStatable

// 구현 세부사항
private var internalValue: T
private(set) var netStatus: NetworkStatus
fileprivate static var observers: [ObserverInfo]  // 파일 스코프 제한 시만 사용
```

### 4.2 규칙

- `@_spi(SendbirdInternal) public` — 기본 가시성. 모든 cross-SDK 노출 선언에 사용
- `@_spi`는 타입 선언에만 붙이면 멤버에 상속되지 않음 → **모든 public 멤버에도 개별 적용**
- `public` 단독 — 거의 사용하지 않음 (ObjC 호환 필수 케이스만)
- `private(set)` — 외부 읽기 전용, 내부 쓰기 가능
- `@_spi(SendbirdInternal) public private(set)` — SPI + 읽기 전용 조합

---

## 5. 코드 구조화

### 5.1 MARK 주석

```swift
// 항상 대시(-) 포함. Xcode 점프 바에 구분선 생성
// MARK: - Section Name

// 타입 본문 내부 섹션
// MARK: - Mutable State (Thread-safe)
// MARK: - Immutable Properties
// MARK: - Dependencies
// MARK: - Initializers

// 프로토콜 준수 extension 앞
// MARK: - EventDelegate
extension SendbirdAuthMain: EventDelegate { ... }
```

### 5.2 Extension 사용 패턴

```swift
// A. 프로토콜 준수는 별도 extension 블록
// MARK: - NSCopying
extension AuthUser: NSCopying {
    open func copy(with zone: NSZone?) -> Any { ... }
}

// B. 접근 수준별 분리
@_spi(SendbirdInternal) public extension String { ... }  // SPI 메서드
public extension String { ... }                          // 진정한 public

// C. #if DEBUG 격리
#if DEBUG
extension LoginEvent {
    @_spi(SendbirdInternal) public func updated(...) -> Self { ... }
}
#endif
```

### 5.3 Import 순서

```swift
import Foundation                    // 항상 첫 번째
#if os(iOS)
    import UIKit                     // 플랫폼 조건부 import
#elseif os(macOS)
    import AppKit
#endif
// Foundation만 필요 없으면 import 생략 가능
// 서드파티 import 없음 (순수 Apple 프레임워크)
```

---

## 6. 문서화 주석

### 6.1 스타일

```swift
// 단일 라인 /// 사용 (/** */ 사용하지 않음)
/// Default constructor.
///
/// - Parameter decoder: `Decoder` instance
public init(from decoder: Decoder) throws { ... }

/// Encodes this object.
///
/// - Parameter encoder: `Encoder` instance
public func encode(to encoder: Encoder) throws { ... }

/// - Since: [NEXT_VERSION]
@_spi(SendbirdInternal) public var newProperty: String
```

### 6.2 버전 표기

새로운 public API 추가 또는 deprecated 처리 시 **구체적 버전 번호 대신 `[NEXT_VERSION]`을 사용**한다. 릴리즈 시점에 실제 버전으로 일괄 치환한다.

```swift
// 새 API 추가 시
/// - Since: [NEXT_VERSION]
@_spi(SendbirdInternal) public func newFeature() { }

// Deprecated 처리 시
@available(*, deprecated, message: "Use newMethod() instead") // [NEXT_VERSION]
@_spi(SendbirdInternal) public func oldMethod() { }
```

### 6.3 인라인 주석

```swift
// TODO: 향후 처리 필요한 항목
// INFO: 팀 내부 참고 사항 (한국어 가능)
// NOTE: 중요 동작 메모
// !!!: 위험한 패턴 경고
// P3, P2, P1: 우선순위 표기
```

---

## 7. 에러 처리 패턴

### 7.1 2단계 에러 시스템

```swift
// Tier 1 — AuthClientError (내부 에러 코드 enum)
public enum AuthClientError: Int, Error {
    case connectionRequired = 800101
    case webSocketConnectionFailed = 800210
    // 도메인별 인라인 주석으로 그룹화
}

// Tier 2 — AuthError (NSError 서브클래스, ObjC 호환)
let error = AuthClientError.connectionRequired.asAuthError
let error = AuthClientError.invalidParameter.asAuthError(message: .emptyParameter("userId"))

// ErrorMessage — 타입화된 에러 메시지 enum
enum ErrorMessage {
    case emptyParameter(_ param: String)
    case invalid(_ param: String)
}
```

### 7.2 에러 전파 규칙

- Completion handler: `(Result?, Error?)` — 둘 다 Optional
- `Decodable` init: `try?` 사용하여 디코딩 실패 시 기본값으로 대체 (에러 전파하지 않음)
- async/callback 브릿지: `withSafeThrowingContinuation` 사용

---

## 8. 콜백 / 클로저 패턴

### 8.1 Typealias 우선

```swift
// HandlerTypes.swift에 모든 콜백 시그니처 정의
public typealias AuthUserHandler = ((_ user: AuthUser?, _ error: AuthError?) -> Void)
public typealias VoidHandler = (() -> Void)
public typealias AuthErrorHandler = ((_ error: AuthError?) -> Void)
```

### 8.2 사용 규칙

```swift
// [weak self] 필수 — 저장되는 클로저
disconnect { [weak self] in
    self?.userConnectionQueue.async {
        self?.resetConnectionState(userId: userId)
        completionHandler()
    }
}

// 옵셔널 체이닝으로 호출
completionHandler?(nil, error)

// 기본값 있는 옵셔널 클로저
func connect(preHook: @escaping () -> Void = {}) { ... }

// 명시적 self 사용 (클로저 내부)
queue.async {
    self.state.disconnect(context: self, completionHandler: completionHandler)
}
```

---

## 9. 프로퍼티 선언 패턴

### 9.1 let vs var

```swift
// let — 불변 (init에서 한 번 설정)
let applicationId: String
let service: QueueService

// var — 가변. 반드시 스레드 안전 메커니즘과 함께
@InternalAtomic var state: ConnectionStatable
private var mutableState = MutableState()  // NSLock으로 보호
```

### 9.2 Property Wrapper 사용

```swift
@InternalAtomic var state: ConnectionStatable           // GCD 기반 원자적 접근
@DependencyWrapper private var dependency: Dependency?   // 지연 약한 참조 DI
@ImmutableDependencyWrapper var config: Config?          // 한 번만 쓰기
@UserDefault("key") var preference: String               // UserDefaults 래핑
@CodableUserDefault("key") var data: SomeModel           // Codable + UserDefaults
@BoundedRange(min: 1, max: 100) var timeout: Int         // 값 범위 제한
@SetOnce var identifier: String                          // 한 번만 설정 가능
```

### 9.3 Lazy 프로퍼티

```swift
// 항상 즉시 실행 클로저 형태
private lazy var markAsReadBucket: BatchedRequestBucket? = { ... }()
@_spi(SendbirdInternal) public lazy var operationQueue: OperationQueue = { ... }()
```

### 9.4 Computed 프로퍼티

```swift
// 단일 표현식은 return 생략
var isConnected: Bool { state is ConnectedState }
var connectState: AuthWebSocketConnectionState { router.webSocketConnectionState }
```

---

## 10. Enum 패턴

### 10.1 Raw Value

```swift
// Int — 에러 코드, 로그 레벨
public enum AuthClientError: Int, Error {
    case connectionRequired = 800101
}

// String — 제품/플랫폼 식별자
public enum SendbirdProduct: String {
    case auth, chat, uikitChat, swiftuiChat
}
```

### 10.2 CodingKeys

```swift
// 공유 CodingKeys enum 사용 (타입별 CodingKeys 아님)
// CodeCodingKeys.swift에 모든 JSON 필드 매핑 집중
enum CodeCodingKeys: String, CodingKey, Codable {
    case userId = "user_id"
    case applicationId = "app_id"
    case expiringSession = "expiring_session"
}
// swiftlint:disable identifier_name — 짧은 이름(id, ts, key) 허용
```

### 10.3 네임스페이스 enum

```swift
// 케이스 없는 enum을 네임스페이스로 사용
enum ConnectionStateEvent {
    struct Connected: ConnectionStateEventable { ... }
    struct Logout: ConnectionStateEventable { ... }
    struct Reconnecting: ConnectionStateEventable { ... }
}
```

### 10.4 Associated Value

```swift
enum LoginKey {
    case authToken(String)
    case none
}

enum ErrorMessage {
    case emptyParameter(_ param: String)  // 라벨 생략(_) 가능
    case invalid(_ param: String)
}
```

---

## 11. 동시성 패턴

### 11.1 세 가지 동시성 레이어 (공존)

```
[GCD — 레거시, 상태 머신에서 주로 사용]
├── SafeSerialQueue       — 데드락 방지 래퍼 (DispatchSpecificKey로 재진입 감지)
├── @InternalAtomic<T>    — DispatchQueue.sync 기반 원자적 프로퍼티
├── NSLock                — EventBroadcaster 델리게이트 스냅샷
└── OperationQueue        — 연결/API 직렬화 (maxConcurrent=1)

[Swift Concurrency — 네트워킹 레이어]
├── actor 프로토콜        — ChatWebSocketEngine, ChatWebSocketClientInterface
├── @globalActor          — SocketSendActor, SocketReceiveActor (WS 송/수신 분리)
├── AsyncEventBroadcaster — actor 기반 AsyncStream 멀티캐스트
├── SafeThrowingContinuation — callback→async 브릿지
└── Task { [weak self] }  — 동기→비동기 전환

[Completion Handler — 공개 API]
├── @escaping 클로저       — connect, authenticate, disconnect
└── QueueService           — 외부 콜백 배달 큐
```

### 11.2 스레드 안전 규칙

- 상태 머신 전환: `SafeSerialQueue userConnectionQueue`에서만 실행
- 개별 프로퍼티: `@InternalAtomic` 또는 `NSLock.withLock { }`
- 델리게이트 순회: 락 하에 스냅샷 복사 후 순회
- `atomicMutate` — read-modify-write 원자적 연산

```swift
// 올바른 패턴
externalParsingStrategies.atomicMutate { strategies in
    strategies[cmdType, default: [:]][identifier] = strategy
}

// 잘못된 패턴 (비원자적 read-modify-write)
var dict = externalParsingStrategies[cmdType] ?? [:]
dict[identifier] = strategy
externalParsingStrategies[cmdType] = dict
```

---

## 12. 아키텍처 패턴

### 12.1 의존성 주입 (Manual Service Locator)

```swift
// Dependency 프로토콜 (서비스 로케이터 계약)
public protocol Dependency: AnyObject {
    var service: QueueService { get }
    var config: SendbirdConfiguration { get }
    var requestQueue: RequestQueue { get }
    // ...
}

// SendbirdAuthMain이 유일한 구체 구현
class SendbirdAuthMain: Dependency { ... }

// 소비자: resolve 후 약한 참조로 접근
@DependencyWrapper private var dependency: Dependency?
func resolve(with dependency: (any Dependency)?) {
    self.dependency = dependency
}
```

### 12.2 State 패턴 (연결 상태 머신)

```
InitializedState → ConnectingState → ConnectedState
                                        ↕
                              ReconnectingState / DelayedConnectingState
                                        ↕
                              InternalDisconnectedState
                                        ↓
                    ExternalDisconnectedState / LogoutState
```

```swift
// 상태 전환은 context.changeState(to:)로만 수행
protocol ConnectionStatable {
    func process(context: ConnectionContext)
    func connect(context: ConnectionContext, ...)
    func disconnect(context: ConnectionContext, ...)
    func didSocketOpen(context: ConnectionContext)
    func didSocketFail(context: ConnectionContext, ...)
    // 모든 메서드에 기본 no-op 구현 제공
}
```

### 12.3 Observer 패턴 (3가지)

```swift
// 1. EventDispatcher — 내부 커맨드 버스
eventDispatcher.add(delegate: sessionManager, priority: .highest)
eventDispatcher.add(delegate: requestQueue)

// 2. EventBroadcaster — 외부 델리게이트 멀티캐스트 (NSMapTable weak)
connectionEventBroadcaster.add(delegate: delegate, forKey: key)

// 3. AsyncEventBroadcaster — Swift Concurrency 스트림 기반
let stream = asyncBroadcaster.subscribe()
for await event in stream { ... }
```

### 12.4 요청 파이프라인

```
Caller → RequestQueue (세션 검증 + 큐잉)
           → CommandRouter
              ├── HTTP: apiOperationQueue → HTTPClient → URLSession
              └── WS:  SocketSendActor → WebSocketManager → ChatWebSocketClient
```

---

## 13. 로깅 패턴

```swift
// 카테고리 기반 정적 로거 사용
Logger.main.info("applicationId: \(applicationId)")
Logger.session.error("Error: \(err)")
Logger.socket.debug("received \(message)")
Logger.http.debug("[Request] \(urlRequest.logDescription)")

// 사용 가능한 카테고리
// .main, .session, .socket, .http, .client, .stat,
// .groupChannel, .openChannel, .feedChannel, .user,
// .localCache, .messageCollection, .messageRepository,
// .messageDatabase, .external
```

---

## 14. 테스트 컨벤션

- 테스트 타겟: `SendbirdAuthTests`
- 테스트 파일 위치: `Tests/SendbirdAuthTests/`
- 테스트 네이밍: `TypeNameTests.swift` (예: `AsyncTimerTests.swift`, `ExternalParsingStrategyTests.swift`)
- 프레임워크: `XCTest`
- 테스트 가능성: WebSocket 엔진 주입 (`injectEngineForTest()`), DI 해결 패턴

---

## 15. SwiftLint 설정

```yaml
# .swiftlint.yml 주요 설정
disabled_rules:
  - trailing_whitespace
  - line_length
  - file_length

# 커스텀 임계값
function_body_length:
  warning: 100
  error: 200
type_body_length:
  warning: 500
  error: 1000
```

---

## 16. 빌드 / 배포

- **XcodeGen**: `project.yml` → `xcodegen generate` → `SendbirdAuthSDK.xcodeproj`
- **타겟 2개**: `SendbirdAuthSDK` (dynamic), `SendbirdAuthSDKStatic` (static)
- **릴리즈**: GitHub Actions 5단계 파이프라인 (`release-workflow.yml`)
- **로컬 릴리즈**: `script/build_xcframework.py`, `script/full_release.py`
- **배포**: SPM (바이너리 타겟), CocoaPods

---

## 17. 오버엔지니어링 방지

### 17.1 원칙

- **요청된 것만 변경한다.** 버그 수정 시 주변 코드를 정리하거나, 단순 기능에 불필요한 설정 옵션을 추가하지 않는다.
- **최소한의 복잡도를 유지한다.** 현재 요구사항을 충족하는 가장 단순한 구현을 선택한다.
- **가상의 미래 요구사항을 설계하지 않는다.** "나중에 필요할 수도 있는" 확장 포인트, 추상화, 제네릭 계층을 미리 만들지 않는다.
- **추상화는 반복이 증명된 후에만 도입한다.** 3번 이상 동일 패턴이 반복될 때까지 중복을 허용한다.

### 17.2 DO

- 한 번만 사용되는 로직은 인라인으로 작성 (헬퍼/유틸리티 함수 불필요)
- 비슷한 코드 3줄이 조기 추상화보다 낫다
- 시스템 경계(사용자 입력, 외부 API)에서만 유효성 검사
- 내부 코드와 프레임워크 보장은 신뢰
- 기존 패턴이 있으면 그것을 따른다 (새 패턴 도입 금지)
- 변경 범위를 요청된 것에만 한정한다
- 가장 단순한 해결책을 먼저 고려한다

### 17.3 DON'T

- 불필요한 추상화: 한 곳에서만 사용되는 로직을 위해 프로토콜/제네릭/헬퍼 클래스 생성
- 미래 대비 설계: 존재하지 않는 요구사항을 위한 확장 포인트, 플러그인 구조, 설정 옵션
- 과도한 에러 처리: 발생할 수 없는 시나리오에 대한 방어 코드. 시스템 경계에서만 검증
- 불필요한 래핑: 표준 라이브러리/프레임워크 기능을 단순히 감싸는 wrapper
- 과도한 코멘트: 자명한 코드에 주석. 변경하지 않은 코드에 docstring/타입 어노테이션 추가
- 범위 초과 리팩토링: 버그 수정 시 주변 코드 정리, 단순 기능 추가 시 아키텍처 개선
- 사용되지 않는 기능 플래그, 하위 호환성 shim 추가
- 삭제한 코드에 `// removed` 주석이나 미사용 `_` 변수 남기기

### 17.4 판단 기준

```
"이 추상화/패턴이 없으면 현재 요구사항을 충족할 수 없는가?"
→ 아니오: 추가하지 않는다.
→ 예: 최소한의 범위로 추가한다.
```

---

## 18. ABI 안정성

### 18.1 절대 원칙

ABI(Application Binary Interface)를 **절대 깨뜨리지 않는다.** 이 SDK는 바이너리 프레임워크(`.xcframework`)로 배포되므로, ABI 호환성이 깨지면 이를 의존하는 모든 모듈이 재빌드해야 한다.

### 18.2 금지 사항 (Breaking Changes)

- `public`/`open` 클래스, 구조체, 프로토콜, enum의 **이름 변경 또는 삭제**
- `public`/`open` 메서드, 프로퍼티의 **시그니처 변경** (파라미터 타입, 반환 타입, 순서)
- `public`/`open` 메서드, 프로퍼티의 **이름 변경 또는 삭제**
- `public` enum에 **기존 케이스 삭제 또는 associated value 변경**
- `open` → `public` 또는 `public` → `internal`로 **접근 레벨 축소**
- `class` → `struct` 또는 `struct` → `class`로 **타입 종류 변경**
- `open class` → `final class`로 변경
- 기존 프로토콜에 **default 구현 없는 required 메서드 추가**
- `@objc` bridging name 변경 (해당되는 경우)

### 18.3 안전한 변경

- `internal`/`private`/`fileprivate` 타입 및 멤버는 자유롭게 변경 가능
- 새로운 `public`/`open` 클래스, 메서드, 프로퍼티 **추가**
- `public` enum에 새 케이스 **추가** (단, 기존 케이스 유지, 소비자의 `@unknown default` 고려)
- 기존 메서드에 **기본값이 있는 파라미터 추가**
- 프로토콜에 **default 구현이 있는** extension 메서드 추가
- `@objc optional` 메서드를 delegate 프로토콜에 추가 (해당되는 경우)
- `@available(*, deprecated, renamed:)` 로 마이그레이션 경로 제공

### 18.4 Deprecated 전환 절차

기존 API를 변경해야 할 때는 반드시 단계적으로 진행한다:

```swift
// 1단계: 새 API 추가 + 기존 API deprecated 처리
@available(*, deprecated, renamed: "newMethodName")
public func oldMethodName() {
    self.newMethodName()
}

public func newMethodName() { /* 새 구현 */ }

// 2단계: 다음 메이저 버전에서 deprecated API 삭제
```

### 18.5 ABI 검증

- PR 생성 시 CI에서 ABI 호환성 자동 검증 (`scripts/compare_abi.sh`, `check-abi-compatibility.yml`)
- ABI 변경이 감지되면 PR 머지 전에 반드시 의도된 변경인지 확인

---

## 19. 주요 금지사항

1. `@_spi(SendbirdInternal)` 없이 `public` 단독 사용 금지
2. 타입별 `CodingKeys` 생성 금지 → `CodeCodingKeys.swift`에 추가
3. 인라인 콜백 시그니처 금지 → `HandlerTypes.swift`에 typealias 정의
4. `Decodable` init에서 `try` 사용 금지 → `try?`로 기본값 대체
5. `var` 사용 시 스레드 안전 메커니즘 없이 가변 상태 노출 금지
6. `SendbirdAuthSDK.xcodeproj` 직접 수정 금지 → `project.yml` 수정 후 `xcodegen generate`
7. 서드파티 의존성 추가 금지
8. co-author에 claude code 등록 금지
9. ABI를 깨는 변경 금지 (public/SPI 시그니처 변경, 삭제, 타입 종류 변경)
10. 요청되지 않은 리팩토링, 개선, 추상화 금지

---

## 20. 코드 작성 체크리스트

새로운 코드 작성/수정 시:

- [ ] `@_spi(SendbirdInternal) public` 접근 제어 확인
- [ ] 새 JSON 필드 → `CodeCodingKeys.swift`에 추가
- [ ] 새 콜백 타입 → `HandlerTypes.swift`에 typealias 추가
- [ ] 가변 상태 → `@InternalAtomic` 또는 `NSLock`/`SafeSerialQueue` 적용
- [ ] 프로토콜 준수 → 별도 extension 블록 + `// MARK: - ProtocolName`
- [ ] 확장 파일 → `Type+SendBirdSDK.swift` 또는 `Type+Sendbird.swift` 네이밍
- [ ] 에러 → `AuthClientError` enum에 코드 추가 + `ErrorMessage`에 메시지 추가
- [ ] 로깅 → 적절한 `Logger.category.level()` 사용
- [ ] `Decodable` init → `try?` 패턴으로 기본값 적용
- [ ] DEBUG 전용 코드 → `#if DEBUG` extension 블록으로 격리
- [ ] ABI 호환성 → public/SPI 시그니처 변경 시 하위호환 유지 확인
- [ ] 오버엔지니어링 → 요청된 범위만 변경했는지 확인
