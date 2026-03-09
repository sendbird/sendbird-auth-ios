# Feature: 로깅 시스템 (Logger)

> 브랜치 작업 시 참조. 최초 생성: 2026-03-06

## Current Status
- 상태: 활성
- 마지막 작업: 2026-03-06
- 다음 할 일: (작업 시 업데이트)

## Key Directories
- `Sources/SendbirdAuth/Logger/` — 카테고리 기반 구조화 로거 (6개 파일, 663줄)
  - `Logger.swift` — 코어 Logger 구조체, 정적 카테고리, 로깅 메서드, 옵저버 관리
  - `Logger.Symbols.swift` — LogSymbol 프로토콜, Priority enum, Categories, DateFormat, Tag, Target, FunctionInfo, Expression
  - `AuthLogLevel.swift` — 로그 레벨 enum (verbose~none, Codable, Comparable)
  - `Logger.Descriptor.swift` — LogDescriptable 프로토콜, InternalDescriptor, ExternalDescriptor
  - `ChatLoggerObserver.swift` — ChatLoggerObserver 클래스, SBLogReceiver 프로토콜, ConsoleReceiver
  - `Logger.Observer.swift` — LoggerObserver 프로토콜, ObserverInfo 래퍼, 리시버 관리

## Architecture

### 카테고리 기반 정적 로거 — 2026-03-06
- **왜**: 모듈별로 로그를 필터링/추적하기 위해 단일 Logger 대신 카테고리 분리 필요
- **결정**: `Logger` 구조체에 정적 프로퍼티로 15개 카테고리 제공
- **Logger 구조체**:
  ```swift
  struct Logger {
      var descriptor: LogDescriptable
      var symbols = [String: LogSymbol]()
      static private(set) var sdkVersion: String?
      fileprivate static var observers: [Logger.ObserverInfo] = [
          .init(observer: chatLoggerObserver)
      ]
  }
  ```
- **카테고리 목록** (OptionSet):
  | 카테고리 | 심볼 | 디스크립터 | 용도 |
  |---|---|---|---|
  | `.main` | `"SendBirdChat"` | External | SDK 메인 이벤트 |
  | `.session` | `"Session"` | External | 세션 생명주기 |
  | `.socket` | `"Socket"` | External | WebSocket 이벤트 (4.21.4~) |
  | `.http` | `"HTTP"` | External | HTTP 요청/응답 (4.21.4~) |
  | `.client` | `"Client"` | Internal | 클라이언트 내부 |
  | `.stat` | `"Stat"` | Internal | 텔레메트리 |
  | `.groupChannel` | `"GroupChannel"` | External | 그룹 채널 |
  | `.openChannel` | `"OpenChannel"` | External | 오픈 채널 |
  | `.feedChannel` | `"FeedChannel"` | External | 피드 채널 |
  | `.user` | `"User"` | External | 사용자 관련 |
  | `.localCache` | `"LocalCache"` | External | 로컬 캐시 |
  | `.messageCollection` | `"MessageCollection"` | External | 메시지 컬렉션 |
  | `.messageRepository` | `"MessageRepo"` | External | 메시지 저장소 |
  | `.messageDatabase` | `"MessageDB"` | External | 메시지 데이터베이스 |
  | `.external` | (nil) | External | 외부 |
- **사용 패턴**:
  ```swift
  Logger.main.info("applicationId: \(applicationId)")
  Logger.session.error("Error: \(err)")
  Logger.socket.debug("received \(message)")
  Logger.http.info("Failed to send request \(request)")
  Logger.stat.debug("DefaultStatCollector is flushing stats.")
  ```

### 로그 레벨 — 2026-03-06
- **왜**: 환경별로 상세도를 조절해야 함
- **결정**: `AuthLogLevel` enum (Int RawValue, Codable, Comparable)
  ```swift
  enum AuthLogLevel: Int {
      case verbose = 0   // 가장 상세
      case debug   = 1
      case info    = 2
      case warning = 3
      case error   = 4   // 심각한 오류만
      case none    = 5   // 로깅 비활성화
  }
  ```
- **필터링**: `observer.limit <= level` 비교로 임계값 이상만 출력
- **기본값**:
  - DEBUG 빌드: `.verbose` (모든 로그)
  - RELEASE 빌드: `.none` (로깅 꺼짐)
  - SDK 초기화 시: `SendbirdAuthMain.logLevel` (기본 `.info`)

### 디스크립터 시스템 (2-Tier) — 2026-03-06
- **왜**: 내부 구현 세부사항과 외부 정보의 출력 정책을 분리해야 함
- **결정**: `LogDescriptable` 프로토콜 + 두 구현체
- **InternalDescriptor**:
  - DEBUG 빌드에서만 출력 (또는 `shouldAlwaysLog=true`)
  - 사용처: `Logger.client`, `Logger.stat`
  - 목적: 릴리즈 빌드에서 내부 세부사항 숨김
- **ExternalDescriptor**:
  - 모든 빌드에서 출력 (DEBUG + RELEASE)
  - 사용처: `Logger.main`, `Logger.session`, `Logger.socket`, `Logger.http` 등
  - 목적: 네트워크, UI, 사용자 동작 등 외부 정보 항상 로깅

### 로그 메시지 포맷 — 2026-03-06
- **왜**: 일관된 로그 형식으로 파싱/분석 용이
- **결정**: Priority 기반 심볼 정렬 후 `[VALUE]` 형태로 조합
- **포맷 구조**:
  ```
  [DateFormat] [LogLevel] [Category] [Target] [FunctionInfo] [Tag] [Message...]
  ```
- **Priority 순서** (낮은 값 = 먼저 출력):
  | Priority | 값 | 설명 |
  |---|---|---|
  | `.target` | 0 | 타겟 (최우선) |
  | `.dateFormat` | 1 | 날짜/시간 |
  | `.categories` | 2 | 카테고리 |
  | `.loggerLevel` | 3 | 로그 레벨 |
  | `.expression` | 4 | 표현식 |
  | `.functionInfo` | 5 | 파일:함수:라인 |
  | `.tag` | 6 | 태그 |
  | `.low` | 7 | 메시지 (마지막) |
- **출력 예시**:
  ```
  [2026.03.06 14:23:45.123 UTC] [info] [Session] [SendbirdChat] [SessionManager:connect:258] Connection established
  ```

### Observer 패턴으로 외부 로그 전달 — 2026-03-06
- **왜**: SDK 소비자가 로그를 자체 시스템에 연동할 수 있어야 함
- **결정**: `LoggerObserver` 프로토콜 + `SBLogReceiver` 프로토콜
- **LoggerObserver 프로토콜**:
  ```swift
  protocol LoggerObserver: AnyObject {
      var identifier: String { get }
      var limit: Logger.Level { get set }       // 옵저버별 로그 레벨 필터
      var categories: Logger.Categories { get set }  // 옵저버별 카테고리 필터
      var receivers: [WeakReference<SBLogReceiver>] { get set }
      func log(message: String)
  }
  ```
- **SBLogReceiver 프로토콜**: `func log(message: String)`
- **리시버 관리**: `add(receiver:)` / `remove(receiver:)` — WeakReference로 순환 참조 방지
- **로그 디스패치**: `receivers.compactMap { $0.value }.forEach { $0.log(message:) }` (nil 참조 자동 정리)
- **옵저버 등록**: `Logger.add(observer:)` / `Logger.remove(observer:)` (정적 메서드)

### ChatLoggerObserver (기본 옵저버) — 2026-03-06
- **왜**: 콘솔 출력이 기본 동작이어야 함
- **결정**: `ChatLoggerObserver` 싱글톤 + `ConsoleReceiver`
- **ConsoleReceiver**:
  ```swift
  class ConsoleReceiver: SBLogReceiver {
      let queue = DispatchQueue(label: "com.sendbird.core.logger_\(UUID())")
      func log(message: String) {
          queue.async { print(message) }  // 비동기 디스패치로 호출자 블로킹 방지
      }
  }
  ```
- **초기화 설정**:
  - DEBUG: `limit = .verbose`, `categories = .all`
  - RELEASE: `limit = .none`, `categories = .all`
  - INSPECTION 빌드: `InspectionReceiver` 추가 (디버깅 도구용)

### 로깅 메서드 — 2026-03-06
- **공개 API** (자동 소스 위치 캡처):
  ```swift
  func error(category:, tag:, filepath: #file, line: #line, funcName: #function, _ symbols: LogSymbol...)
  func warning(category:, tag:, filepath:, line:, funcName:, _ symbols: LogSymbol...)
  func info(category:, tag:, filepath:, line:, funcName:, _ symbols: LogSymbol...)
  func debug(category:, tag:, filepath:, line:, funcName:, _ symbols: LogSymbol...)
  func verbose(category:, tag:, filepath:, line:, funcName:, _ symbols: LogSymbol...)
  func send(level:, category:, tag:, filepath:, line:, funcName:, _ symbols: LogSymbol...)
  func error(errorMessage: ErrorMessage)  // 에러 편의 메서드
  ```
- **가변 인자**: `LogSymbol...`로 여러 심볼을 조합 가능

### 설정 API — 2026-03-06
- **전역 로그 레벨**:
  ```swift
  Logger.setLoggerLevel(_ level: AuthLogLevel)
  // 모든 옵저버의 limit을 일괄 변경
  ```
- **전역 카테고리 필터**:
  ```swift
  Logger.setCategories(_ categories: Logger.Categories)
  // 모든 옵저버의 categories를 일괄 변경
  ```
- **SDK 초기화 시**: `Logger.setLoggerLevel(logLevel)` 호출 (`SendbirdAuthMain.swift`)

### 스레드 안전 — 2026-03-06
- **리시버별 큐**: 각 `ConsoleReceiver`가 전용 직렬 DispatchQueue 소유
- **비동기 디스패치**: `queue.async { print(message) }` — 호출자 블로킹 방지
- **약한 참조**: `ObserverInfo`와 `SBLogReceiver`에 weak reference — 메모리 누수 방지
- **정적 옵저버 목록**: `add()`/`remove()`로만 수정

## Learnings
> (작업 중 새로 알게 된 것을 날짜와 함께 기록)

## Known Issues
> (미해결 이슈)

## Solved Problems
> (해결된 문제 이력)

## Dependencies
- 의존: (없음 — 가장 하위 레이어)
- 피의존: 모든 모듈 (Connection, Session, Client, Stats 등) — 38개 이상 파일에서 사용
