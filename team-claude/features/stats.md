# Feature: 텔레메트리 (Stats)

> 브랜치 작업 시 참조. 최초 생성: 2026-03-06

## Current Status
- 상태: 활성
- 마지막 작업: 2026-03-06
- 다음 할 일: (작업 시 업데이트)

## Key Directories
- `Sources/SendbirdAuth/Stats/` — 텔레메트리 수집/전송 (30개 파일)
  - `StatManager.swift` — 중앙 매니저 (3개 컬렉터 조율, 상태 전환, 재시도)
  - `StatManagerDelegate.swift` — 컬렉터→매니저 콜백 프로토콜
  - `API/`
    - `StatAPIClient.swift` — HTTP 전송 클라이언트
    - `StatAPIClientable.swift` — 전송 추상화 프로토콜
  - `Flusher/`
    - `RandomStatRequestBalancer.swift` — 랜덤 지연 요청 분배
    - `StatRequestBalancer.swift` — 요청 분배 베이스 프로토콜
  - `StatCollector/`
    - `StatCollectorContract.swift` — 컬렉터 공통 프로토콜
    - `DefaultStatCollector.swift` — WS/API 통계 (인터벌 기반)
    - `DailyStatCollector.swift` — 일별 집계 (중복제거 캐시)
    - `NotificationStatCollector.swift` — 알림 통계 (실시간, 중복제거)
  - `Storage/`
    - `StatStorage.swift` — 저장소 프로토콜
    - `StatStorageHelper.swift` — 제네릭 저장소 구현 (스레드 안전 큐)
    - `DefaultRecordStatStorage.swift` — 기본 통계 저장 (statId 키)
    - `DailyRecordStatStorage.swift` — 일별 통계 저장 (날짜+타입 키)
    - `NotificationRecordStatStorage.swift` — 알림 통계 저장
    - `StatStorageKeyType.swift` — 저장소 키 설정 프로토콜
  - `Model/`
    - `BaseStat.swift` — 베이스 클래스 (프로토콜, 타임스탬프, statType, runtimeId)
    - `StatType.swift` — 통계 유형 enum
    - `DefaultRecordStat.swift` — 기본 레코드 베이스
    - `DailyRecordStat.swift` — 일별 집계 + DailyRecordKey
    - `NotificationRecordStat.swift` — 알림 레코드 베이스
    - `DailyRecordStatType.swift` — 일별 통계 프로토콜
    - `StatCodableWrapper.swift` — 제네릭 Codable 래퍼
  - `StatRecordType/` — 구체 통계 타입
    - `WebSocketConnectStat.swift` — WS 연결 (지연시간, 성공, 에러, 시도 횟수)
    - `WebSocketDisconnectedStat.swift` — WS 연결 해제 (사유, 에러)
    - `APIResultStat.swift` — API 결과 (엔드포인트, 메서드, 지연시간, 성공)
    - `NotificationStat.swift` — 알림 (액션, 템플릿 키, 채널 URL, 메시지 ID, 태그)
  - `ExternalStatMapper.swift` — 외부 통계 핸들러 레지스트리
- `Sources/SendbirdAuth/Common/Model/Stats/`
  - `StatConfig.swift` — 통계 수집/전송 설정

## Architecture

### StatManager 상태 머신 — 2026-03-06
- **왜**: 통계 수집/전송의 활성화 상태를 명확히 관리해야 함
- **결정**: 4-상태 머신으로 수집/전송 제어
  ```swift
  enum State {
      case pending      // 초기 상태: 수집 가능, 전송 불가
      case enabled      // 수집 + 전송 가능
      case collectOnly  // 수집만 가능, 전송 불가 (재시도 소진)
      case disabled     // 수집/전송 모두 불가 (로그아웃)
  }
  ```
- **상태 전환**:
  ```
  pending ──LOGI + stats 허용──→ enabled
  pending ──LOGI + collect only──→ collectOnly
  any ──────────logout────────→ disabled
  any ───재시도 한도 초과──→ collectOnly
  collectOnly ──새 업로드 허용──→ enabled (LOGI에서)
  ```
- **isAppendable**: `state != .disabled`
- **isUploadable**: `state == .enabled`

### 3개 컬렉터 체계 — 2026-03-06
- **왜**: 통계 유형별로 수집/전송 방식이 다름
- **결정**: `StatCollectorContract` 프로토콜 + 3개 구체 컬렉터

| 측면 | DefaultStatCollector | DailyStatCollector | NotificationStatCollector |
|---|---|---|---|
| **통계 유형** | ws:connect, ws:disconnect, api:result, feature:local_cache_event | feature:local_cache (일별) | noti:stats |
| **수집 방식** | 연결/API 호출 시 | 일별 집계 | 푸시 이벤트 |
| **저장소 키** | UUID (statId) | 날짜+타입 (DailyRecordKey) | UUID (statId) |
| **초기 상태** | enabled | enabled | **disabled** |
| **전송 트리거** | 인터벌(3시간) 또는 카운트(100+) | 1일 1회 (이전 날짜만) | 실시간 (활성화 시) |
| **중복제거** | statId 교체 | 날짜+타입별 머지 | 해시 기반 2-tier 캐시 |
| **HTTP 엔드포인트** | `/api/v1/sdk_statistics` | `/api/v1/sdk_statistics` | `/api/v1/notification_statistics` |
| **설정 소스** | 서버 (LOGI) + 하드코딩 | 하드코딩 | 서버 (LOGI) |
| **배치 크기** | 1000 | 1000 | 1000 |
| **요청 지터** | 3분 랜덤 | 3분 랜덤 | 20초 랜덤 |

### StatConfig 설정 — 2026-03-06
- **위치**: `Common/Model/Stats/StatConfig.swift`
- **필드** (Codable, JSON 매핑):
  ```swift
  class StatConfig: Codable {
      let minStatCount: Int           // 전송 전 최소 수량 (기본 100)
      let minInterval: Int64          // 전송 간 최소 간격 (초, 기본 3시간)
      let maxStatCountPerRequest: Int // 배치당 최대 수량 (1000)
      let lowerThreshold: Int         // 전송 고려 최소치 (10)
      let requestDelayRange: Int      // 랜덤 지터 (초, 기본 3분)
      let modStatCount: Int = 20      // fromAuth 전송 시 모듈로 체크
  }
  ```

### DefaultStat + RealtimeStat 이중 통계 타입 — 2026-03-06
- **왜**: 집계 통계(기간별 평균)와 실시간 이벤트 통계는 수집/전송 방식이 다름
- **결정**: `DefaultStat` (배치 집계) / `NotificationStat` (즉시 전송) 분리
- **StatType enum**:
  ```swift
  enum StatType {
      case webSocketConnect      // "ws:connect"
      case webSocketDisconnect   // "ws:disconnect"
      case apiResult             // "api:result"
      case featureLocalCache     // "feature:local_cache_event"
      case notificationStats     // "noti:stats"
      case aiAgentStats          // "ai_agent:stats"
  }
  ```

### BaseStat 모델 — 2026-03-06
- **왜**: 모든 통계 유형의 공통 인터페이스 필요
- **결정**: `BaseStatType` 프로토콜 (Codable, Hashable, AnyObject)
  ```swift
  protocol BaseStatType: Codable, CustomStringConvertible, Hashable, AnyObject {
      var timestamp: Int64 { get }              // 밀리초
      var statType: StatType { get }
      var data: [String: AnyCodable]? { get }   // 제네릭 확장 포인트
      var statId: String? { get set }           // 고유 ID
      var isUploaded: Bool { get set }          // 업로드 추적
      var runtimeId: String? { get }            // 세션 런타임 ID
      func markAsUploaded()
  }
  ```

### 구체 통계 타입 — 2026-03-06
- **WebSocketConnectStat**: 지연시간(latency, logiLatency), 성공 여부, 에러 코드, 시도 횟수(accumTrial), 연결 ID, isSoftRateLimited
- **WebSocketDisconnectedStat**: 연결 해제 사유(DisconnectReason enum), 에러 추적
- **APIResultStat**: 엔드포인트, HTTP 메서드, 지연시간, 성공 여부
- **NotificationStat**: 액션, 템플릿 키, 채널 URL, 메시지 ID, 태그

### Storage 아키텍처 — 2026-03-06
- **왜**: 수집과 전송 책임을 분리하여 독립적으로 교체/테스트 가능하게 함
- **결정**: `StatStorageHelper<Key, RecordStatType>` 제네릭 저장소
  ```
  StatStorageHelper<Key, RecordStatType>
  ├── userDefaults (영속 저장)
  │   ├── lastSentAt (Date)
  │   └── internalStatWrappers [Key: StatCodableWrapper<RecordStatType>]
  └── queue (SafeSerialQueue — 스레드 안전)
  ```
- **저장소 유형**:
  | 저장소 | 키 타입 | 키 예시 |
  |---|---|---|
  | `DefaultRecordStatStorage` | `String` (statId UUID) | `"550e8400-..."` |
  | `DailyRecordStatStorage` | `DailyRecordKey` | `"20260306_feature:local_cache"` |
  | `NotificationRecordStatStorage` | `String` (statId UUID) | `"550e8400-..."` |
- **축적 방법**:
  - Default: `saveStats([stat])` — 동일 statId 교체
  - Daily: `upsert(stat)` — 동일 키 존재 시 중첩 데이터 재귀적 머지
  - Notification: `saveStats([stat])` — 동일 statId 교체
- **영속화**: `UserDefaults(suiteName: "com.sendbird.sdk.stat.storage")`

### Flusher / 전송 메커니즘 — 2026-03-06
- **왜**: 효율적인 배치 전송 + 서버 부하 분산
- **결정**: 이벤트 기반 + 지연 전송 (고정 주기 타이머 없음)
- **전송 트리거**:
  1. **초기 플러시** (pending → enabled): `trySendStats(fromAuth: true)` 호출
  2. **진행 중 플러시**: `append()` 호출 시 임계값 확인
  3. **타임아웃 이벤트**: WS 지연시간 통계
- **전송 결정 로직** (DefaultStatCollector):
  ```swift
  if fromAuth {
      return minStatCount >= 0 && (count == minStatCount || count % modStatCount == 0)
  } else {
      return (now - lastSentAt) > minInterval && count >= lowerThreshold
  }
  ```
- **요청 분산**: `RandomStatRequestBalancer.distributeRequest(delayRange:)` — 0~delayRange초 랜덤 sleep
- **배치 분할**: `maxStatCountPerRequest` (1000)씩 분할, 순차 전송 + 랜덤 지터
- **재시도 정책**:
  - `maxRetryCount: 20`
  - 실패 시: `retryCount -= 1`
  - 소진 시: `state → .collectOnly`
  - 특정 에러 (`.statUploadNotAllowed`): 즉시 `.collectOnly`
- **업로드 추적**: 성공 시 `stat.isUploaded = true` → `removeUploadedStats()` 정리

### NotificationStat 중복제거 — 2026-03-06
- **왜**: 동일 알림 이벤트의 중복 수집 방지
- **결정**: 2-tier 해시 캐시
  - `appendedStatDedupCache`: 수집 시 중복 확인
  - `sentStatDedupCache`: 전송 완료된 통계 중복 확인
  - 해시 키: `hash(action_channelURL_messageId)`
  - 별도 `statCacheQueue`로 캐시 접근 동기화

### DailyStat 집계 — 2026-03-06
- **왜**: 로컬 캐시 등의 일별 집계가 필요
- **결정**: `DailyRecordKey` (날짜 "yyyyMMdd" + statType)로 upsert
  - 오늘 날짜 통계는 전송에서 **제외** (과거 날짜만 전송)
  - 동일 키 존재 시 중첩 데이터 재귀적 머지 (집계)

### HTTP 전송 — 2026-03-06
- **엔드포인트**:
  | 통계 유형 | 엔드포인트 |
  |---|---|
  | 기본/일별 | `POST /api/v1/sdk_statistics` |
  | AI 에이전트 | `POST /api/v1/sdk_ai_agent_statistics` |
  | 알림 | `POST /api/v1/notification_statistics` |
- **요청 포맷**:
  ```json
  {
      "log_entries": [
          {
              "ts": 1704067200000,
              "stat_type": "ws:connect",
              "data": { ... },
              "stat_id": "550e8400-...",
              "runtime_id": "session-uuid"
          }
      ],
      "device_id": "device-uuid"
  }
  ```
- **stat_id 제거**: 전송 전 statId 복사본에서 제거 (서버에 불필요)
- **device_id**: `UserDefaults` 키 `"com.sendbird.sdk.stat.unique_device_id"`, 없으면 UUID 생성

### 수집 API — 2026-03-06
- **주요 메서드**:
  ```swift
  // 범용 수집
  func append<RecordStatType: BaseStatType>(_ stat: RecordStatType, fromAuth: Bool? = nil, completion: VoidHandler?)

  // WS 이벤트 수집
  func append(logiEvent: LoginEvent)              // LOGI 성공/실패
  func append(failedEvent: WebSocketStatEvent.WebSocketFailedEvent)
  func append(timeoutEvent: WebSocketStatEvent.WebSocketLoginTimeoutEvent)
  func append(disconnectEvent: WebSocketStatEvent.WebSocketDisconnectEvent)
  func append(reconnectTimeoutEvent: WebSocketStatEvent.WebSocketReconnectLoginTimeoutEvent)
  ```
- **외부 통계 지원**:
  ```swift
  ExternalStatMapper.register(statType:handler:)
  ExternalStatMapper.unregister(statType:)
  ExternalStatMapper.map(type:data:timestamp:...)
  ```
  - `NSLock`으로 정적 `handlers` 딕셔너리 보호

### 서버 설정 통합 — 2026-03-06
- **LOGI 응답에서 설정 수신**:
  ```swift
  // EventDelegate에서 LOGI 수신 시
  if let defaultConfig = loginEvent.appInfo?.defaultConfig {
      defaultStatCollector?.statConfig = defaultConfig
  }
  if let notificationConfig = loginEvent.appInfo?.notificationConfig {
      notificationStatCollector?.statConfig = notificationConfig
      notificationStatCollector?.enabled = true
  }

  if command.isStatsCollectAllowed {
      if command.isStatsUploadAllowed { enable() }
      else { changeToCollectOnly() }
  } else {
      disable()
  }
  ```

### 스레드 안전 — 2026-03-06
- **StatManager**: `OperationQueue` (직렬, background QoS)
- **각 컬렉터**: 전용 `DispatchQueue` (직렬, background QoS) + `isFlushing: Bool` 플래그
- **Storage**: `SafeSerialQueue`로 UserDefaults 접근 래핑
- **NotificationStatCollector**: 별도 `statCacheQueue`로 캐시 보호
- **ExternalStatMapper**: `NSLock`으로 핸들러 딕셔너리 보호
- **설계 원칙**: 글로벌 잠금 없음, 컬렉터별 격리, 약한 델리게이션으로 데드락 방지

### 생명주기 — 2026-03-06
- **SDK 초기화** → `StatManager` 생성, `state = .pending`
- **LOGI 성공** → 서버 설정 적용, `enable()` 또는 `changeToCollectOnly()`
- **WS 이벤트** → 통계 수집 (WebSocketStatEvent)
  - `WebSocketStartEvent` → connectionStartedAt 기록
  - `WebSocketOpenedEvent` → wsOpenedEvent 보존
  - `WebSocketFailedEvent` → WebSocketConnectStat 생성
  - `WebSocketLoginTimeoutEvent` → 타임아웃 통계 생성
- **로그아웃** → `disable()` → 모든 통계 삭제
- **전송 실패 반복** → `retryCount` 소진 → `collectOnly`
- **재연결 후 LOGI** → 설정 재적용, 업로드 재개 가능

## Learnings
> (작업 중 새로 알게 된 것을 날짜와 함께 기록)

## Known Issues
> (미해결 이슈)

## Solved Problems
> (해결된 문제 이력)

## Dependencies
- 의존: Client (`StatAPIClient` — HTTP 전송), Common/Model/Stats (`StatConfig`), Connection (WS 이벤트 수신)
- 피의존: (외부 소비자 없음 — 내부 수집 전용. `ExternalStatMapper`로 확장 가능)
