# Feature: WebSocket 연결 관리 (Connection)

> 브랜치 작업 시 참조. 최초 생성: 2026-03-06

## Current Status
- 상태: 활성
- 마지막 작업: 2026-03-06
- 다음 할 일: (작업 시 업데이트)

## Key Directories
- `Sources/SendbirdAuth/Connection/` — 상태 머신 + 델리게이트 + 브로드캐스터
  - `State/` — 9개 연결 상태 (State 패턴) + `UserConnectionManager` (상태 머신 오케스트레이터)
  - `State/LoginKey.swift` — 인증 토큰 enum 래퍼 (`.authToken(String)` / `.none`)
  - `State/ReconnectingTrigger.swift` — 재연결 트리거 사유 enum (9가지)
  - `Delegates/` — `AuthConnectionDelegate`, `AuthSessionDelegate`, `NetworkDelegate`, `InternalConnectionDelegate`
  - `Broadcaster/` — `ConnectionEventBroadcaster`, `SessionEventBroadcaster`, `NetworkEventBroadcaster`, `InternalConnectionEventBroadcaster`
  - `Manager/` — `DeviceConnectionManager` (디바이스 생명주기 + 네트워크 Reachability)
  - `DataSource/` — `SessionData`, `ConnectionStateDataSource`, `AuthenticationDataSource`

## Architecture

### 9-State State Machine — 2026-03-06
- **왜**: WebSocket 연결은 단순 on/off가 아니라 reconnect, delay, logout 등 복잡한 생명주기를 가짐
- **결정**: `ConnectionStatable` 프로토콜 + 9개 구체 상태 클래스로 State 패턴 구현
- **상태 전이도**:
  ```
  InitializedState ──connect()──→ ConnectingState ──LOGI 성공──→ ConnectedState
       ↑                              │                              │
       │                         BUSY 이벤트                    소켓 close/fail
       │                              ↓                         앱 백그라운드
  LogoutState              DelayedConnectingState                    │
       ↑                         타이머 만료 ↓                       ↓
       │                      ReconnectingState ←── InternalDisconnectedState
  disconnect()                     │                         │
       ↑                      max retry 초과             connect() 호출
       │                           ↓                         ↓
  ExternalDisconnectedState ← disconnectWebSocket()    ConnectingState
  ```
- **주의사항**: 상태 전환은 반드시 `context.changeState(to:)` 사용. `SafeSerialQueue`에서만 실행

### ConnectionStatable 프로토콜 — 2026-03-06
- **인터페이스**:
  ```swift
  protocol ConnectionStatable {
      var reconnectedBy: ReconnectingTrigger? { get }
      func process(context: ConnectionContext)
      func connect(context:, loginKey:, sessionKey:, userHandler:)
      func disconnect(context:, completionHandler:)
      func disconnectWebSocket(context:, completionHandler:)
      func didEnterBackground(context:)
      func reconnect(context:, sessionKey:, reconnectedBy:) -> Bool
      func didSocketOpen(context:)
      func didSocketClose(context:, code:)
      func didSocketFail(context:, error:)
      func didReceiveLOGI(context:, command: LoginEvent)
      func didReceiveBUSY(context:, command: BusyEvent)
  }
  ```
- **기본 구현**: extension으로 대부분 메서드의 기본 no-op 구현 제공. `process()`, `connect()`, `disconnect()`, `disconnectWebSocket()`, `reconnect()`만 각 상태에서 필수 구현

### 9개 상태 상세 — 2026-03-06

#### 1. InitializedState
- **진입**: SDK 초기화 또는 LogoutState에서 전환
- **동작**: 유휴 상태. `connect()` → ConnectingState, `disconnect()` → LogoutState
- **reconnect()**: false 반환 (세션 없음)

#### 2. ConnectingState
- **진입**: `connect()` 호출 시
- **동작**: WebSocket URL 생성 → CONNECT 전송 → Connecting 이벤트 디스패치 → 로그인 타임아웃 타이머 설정
- **로그인 재시도**: 기본 1회 재시도 후 실패 시 reconnect 전환
- **LOGI 성공** → ConnectedState
- **BUSY 수신** → DelayedConnectingState (서버 과부하)
- **소켓 열림** → 로그인 타임아웃 시작 (`websocketTimeout` 설정값)
- **백그라운드** → 세션 저장 또는 LogoutState 전환

#### 3. ConnectedState
- **진입**: ConnectingState 또는 ReconnectingState에서 LOGI 성공 시
- **동작**: Connected 이벤트 디스패치, 로그인 핸들러에 성공 콜백
- **소켓 close/fail** → InternalDisconnectedState (자동 재연결 활성화)
- **백그라운드** → InternalDisconnectedState
- **BUSY** → DelayedConnectingState

#### 4. DelayedConnectingState
- **진입**: 서버 BUSY 이벤트 수신 시
- **동작**: 소켓 disconnect → ConnectionDelayed 이벤트 → `retryAfter` 초 후 타이머 실행
- **타이머 만료** → ReconnectingState
- **`connect()` 호출** → 핸들러 추가, 남은 대기시간 계산하여 지연 이벤트 디스패치
- **백그라운드** → BusyEventWrapper에 상태 저장 후 InternalDisconnectedState

#### 5. ReconnectingState
- **진입**: 인증된 상태에서 연결 끊김 + 세션 키 보유
- **동작**: ReconnectingStarted 이벤트 → 백오프 타이머 → Reconnecting 이벤트 → 소켓 재연결
- **LOGI 성공** → ConnectedState (isReconnected=true)
- **소켓 실패** → retryCount 증가, 새 ReconnectingState 생성
- **disconnect()** → 재연결 취소, ReconnectionCanceled 이벤트, LogoutState
- **BUSY** → DelayedConnectingState

#### 6. InternalDisconnectedState
- **진입**: 네트워크 오류, 소켓 close, 백그라운드 전환
- **동작**: 소켓 disconnect → InternalDisconnected 이벤트 디스패치
  - `shouldRetry=true` + task 존재 → ReconnectingState 전환
  - busyEventWrapper 존재 → DelayedConnectingState 지연 재개 가능
- **reconnect()** → task의 sessionKey 업데이트 후 ReconnectingState 전환
- **connect()** → ConnectingState (새 연결)

#### 7. ExternalDisconnectedState
- **진입**: `disconnectWebSocket()` 호출 (사용자 의도적 소켓 disconnect, 세션 유지)
- **동작**: 소켓 disconnect → ExternalDisconnected 이벤트 → completionHandler 호출
- **connect()** → ConnectingState
- **reconnect()** → `reconnectedBy==.manual`일 때만 ReconnectingState 전환

#### 8. LogoutState
- **진입**: `disconnect()` 호출 또는 최종 에러 상태
- **동작**: "Clear local data" 로그 → Logout 이벤트 → 소켓 disconnect → InitializedState 전환 → completionHandler 호출
- **모든 세션 상태 클리어**

#### 9. (LoginKey / ReconnectingTrigger는 상태가 아닌 보조 enum)

### WebSocketManager (ConnectionStateMachine) — 2026-03-06
- **왜**: 상태 전환의 중앙 조율자 필요
- **결정**: `WebSocketManager` 클래스 (`UserConnectionManager` alias)가 상태 머신 역할
- **스레드 안전**:
  - `@InternalAtomic` 프로퍼티 래퍼로 `state` 보호
  - `SafeSerialQueue`로 모든 상태 전환 직렬화
  - 외부 호출 (connect, disconnect) → `queue.async`
  - `reconnect()` → `queue.sync` (즉시 결과 반환 필요)
- **상태 쿼리**:
  ```swift
  var isConnecting: Bool { state is ConnectingState }
  var isReconnecting: Bool { state is ReconnectingState }
  var isConnected: Bool { state is ConnectedState }
  var isDisconnected: Bool { state is LogoutState || state is InternalDisconnectedState }
  ```
- **주의사항**: `state` didSet에서 `state.process(context: self)` 호출로 자동 상태 초기화

### AuthConnectionDelegate + AuthSessionDelegate — 2026-03-06
- **왜**: 상태 전환 이벤트를 외부(SDK 소비자)에 알리는 인터페이스 필요
- **AuthConnectionDelegate** (`@objc SBDAuthConnectionDelegate`):
  ```swift
  optional func didStartReconnection()
  optional func didSucceedReconnection()
  optional func didFailReconnection()
  optional func didConnect(userId: String)
  optional func didDisconnect(userId: String)
  optional func didDelayConnection(retryAfter: UInt)  // Since 4.34.0
  ```
- **AuthSessionDelegate** (`@objc SBDAuthSessionDelegate`):
  ```swift
  func sessionTokenDidRequire(successCompletion:, failCompletion:)  // 필수
  func sessionWasClosed()                                           // 필수
  optional func sessionWasRefreshed()
  optional func sessionDidHaveError(_ error: NSError)
  ```
- **InternalConnectionDelegate** (`@objc SBDInternalConnectionDelegate`):
  ```swift
  func didInternalDisconnect()
  func didExternalDisconnect()
  ```
- **NetworkDelegate**: 네트워크 재연결 이벤트 콜백

### EventBroadcaster 멀티캐스팅 — 2026-03-06
- **왜**: 여러 델리게이트에 동시 이벤트 전달 필요
- **결정**: `EventBroadcaster` 베이스 클래스 + 구체 브로드캐스터
- **구현 요소**:
  - `NSMapTable<NSString, Delegate>` — 델리게이트 저장 (weak/strong 설정 가능)
  - `NSLock` — 동시 접근 보호 (잠금 하에 스냅샷 복사 후 순회)
  - `QueueService` — 적절한 큐에서 콜백 디스패치 (메인 또는 백그라운드)
- **4개 브로드캐스터**:
  | 브로드캐스터 | 전달 이벤트 |
  |---|---|
  | `ConnectionEventBroadcaster` | startedReconnection, succeededReconnection, failedReconnection, connected, disconnected, delayedConnection |
  | `SessionEventBroadcaster` | 세션 토큰 요청, 세션 닫힘 등 |
  | `NetworkEventBroadcaster` | reconnected (네트워크 복구) |
  | `InternalConnectionEventBroadcaster` | internalDisconnected, externalDisconnected |

### DeviceConnectionManager — 2026-03-06
- **왜**: 디바이스 생명주기(포그라운드/백그라운드)와 네트워크 상태 변화에 따른 자동 연결 관리 필요
- **결정**: `DeviceConnectionManager`가 `EventDelegate`를 구현하여 연결 상태 이벤트 수신 → 브로드캐스터로 전달
- **포그라운드 진입** (`enteredForeground()`):
  - `isForeground = true`
  - `sessionManager?.reconnect(reconnectedBy: .enteringForeground)` 호출
- **백그라운드 진입** (`enteredBackground()`):
  - `isForeground = false`
  - `webSocketManager?.enterBackground(completionHandler:)` 호출
- **네트워크 Reachability**:
  - `Reachability` 모니터로 네트워크 상태 감시
  - 네트워크 복구 시 `.networkReachability` 트리거로 재연결
  - `isOnline` / `isOffline` 프로퍼티 제공
- **이벤트 위임**: ConnectionStateEvent를 수신하여 각 브로드캐스터로 분배
  - `Connected` → `broadcaster.succeededReconnection()` 또는 `.connected(userId:)`
  - `Logout` → `broadcaster.disconnected(userId:)`
  - `ReconnectingStarted` → `broadcaster.startedReconnection()`
  - `ReconnectionFailed` → `broadcaster.failedReconnection()`
  - `ConnectionDelayed` → `broadcaster.delayedConnection(retryAfter:)`

### Reconnection 전략 (Exponential Backoff) — 2026-03-06
- **왜**: 즉시 재연결은 서버 부하 가중, 일정한 간격은 비효율적
- **결정**: `ReconnectionTask`를 통한 지수 백오프
- **공식**: `min(baseInterval * (multiplier ^ retryCount), maximumInterval)`
- **기본 설정**:
  ```
  baseInterval: 2초
  multiplier: 2
  maximumInterval: 20초
  maximumRetryCount: -1 (무한)
  ```
- **재시도 시퀀스**: 2초 → 4초 → 8초 → 16초 → 20초(캡) → 20초...
- **최초 연결**: 기본 1회 재시도 후 세션 존재 시 reconnection 전환
- **재연결 트리거** (`ReconnectingTrigger`):
  | 트리거 | 설명 |
  |---|---|
  | `.manual` | 사용자 명시적 reconnect() 호출 |
  | `.networkReachability` | 네트워크 unavailable → available 전환 |
  | `.enteringForeground` | 앱 포그라운드 복귀 |
  | `.watchdog` | Ping/pong 타임아웃 |
  | `.refreshedSessionKey` | 세션 키 갱신 완료 |
  | `.sessionValidation` | 세션 유효성 검사 트리거 |
  | `.cachedSessionKey` | 캐시된 세션으로 재연결 |
  | `.webSocketError` | WebSocket 연결 오류 |
  | `.busyServer` | 서버 BUSY 이벤트 후 재연결 |

### LoginKey Enum — 2026-03-06
- `.authToken(String)` — 인증 토큰 포함
- `.none` — 토큰 없음 (Guest)
- `authToken: String?` 계산 프로퍼티로 토큰 추출

## Learnings
> (작업 중 새로 알게 된 것을 날짜와 함께 기록)

## Known Issues
> (미해결 이슈)

## Solved Problems
> (해결된 문제 이력)

## Dependencies
- 의존: Client (`ChatWebSocketClient` WebSocket 엔진), Common/Commands (`LoginEvent`, `BusyEvent`, `CommandType`), Common/Concurrency (`SafeSerialQueue`)
- 피의존: `SendbirdAuthMain` (상태 머신 소유), Session (연결 이벤트 수신 + 세션 만료 시 재연결 트리거), Stats (연결 이벤트 수집)
