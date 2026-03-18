### New Features

#### 멀티 인스턴스 지원 (`SendbirdAuth`, `AuthInstanceIdentifier`)

- `SendbirdAuth.getOrCreate(params:)` — `appId` + `apiHostUrl` 조합으로 인스턴스를 생성하거나 기존 인스턴스를 반환
- `SendbirdAuth.getInstance(_:)` / `removeInstance(_:)` / `clearAllInstances()` 추가
- `AuthInstanceIdentifier` — 인스턴스 식별에 사용되는 새 public 타입 (`appId` + `apiHostUrl`)

#### 크로스-SDK 세션 공유 (`SessionProvider`, `SessionObserver`)

- `SessionProvider` 프로토콜 — 여러 SDK 인스턴스 간 세션 공유 및 갱신 조율
- `SessionObserver` 프로토콜 — 세션 변경/갱신 요청/갱신 실패 이벤트 수신
- `InternalInitParams.sessionProvider` / `canRefreshSession` — 세션 갱신 주체 제어 (`false` 설정 시 다른 SDK에 위임)

#### 커스텀 예외 파서 (`APIExceptionParser`)

- `APIExceptionParser` 프로토콜 — 4xx 응답 파싱 커스터마이징
- `DefaultExceptionParser` — Chat API 기본 포맷 파서 (`{"error": true, "code": ..., "message": ...}`)
- `InternalInitParams.exceptionParser`로 주입 가능

#### 요청 헤더 인터셉터 (`APIHeaderInterceptor`, `APIHeaderKey`)

- `APIHeaderInterceptor` 프로토콜 — 기본 헤더를 받아 최종 헤더를 반환하는 변환 인터페이스
- `APIHeaderKey` 열거형 — HTTP 헤더 키 타입 안전 정의
- `InternalInitParams.headerInterceptor`로 주입 가능

### Improvements

#### 인스턴스별 격리 (`SendbirdAuthMain`)

- `decoder` — 전역 `SendbirdAuth.authDecoder` 대신 인스턴스별 독립 `JSONDecoder` 소유
- `preference` — 인스턴스별 독립 `LocalPreferences` (key: `com.sendbird.sdk.ios.<appId>_<apiHostUrl>`)
- `destroy(completionHandler:)` — disconnect 후 reset을 명시적으로 수행하는 라이프사이클 메서드 추가

#### SessionManager Credential 모델 (`SessionManager.Credential`)

- `.initialized` / `.active(applicationId:userId:)` 상태로 명시적 관리
- `applicationId`, `userId`가 optional로 변경되어 미초기화 상태 표현 가능

### Deprecated

- `SendbirdAuth.authDecoder` → `SendbirdAuthMain.decoder` 사용
- `SendbirdAuth.pref` → `SendbirdAuthMain.preference` 사용
- `SendbirdAuth.isInitialized` (static) / `isInitializedWithoutWarning` → `isInitialized(appId:apiHostUrl:)` 사용
