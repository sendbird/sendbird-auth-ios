# auth-ios Team Common Rules

> 모든 작업자가 공유하는 핵심 규칙. 상세 내용은 `team-claude/code_conventions.md` 참조.

## Team-Common Rules (iOS 팀 공용)

> 아래 규칙은 Sendbird iOS 팀 전체 프로젝트(chat-ios, uikit-ios, ai-agent-ios, auth-ios)에 동일하게 적용됩니다.

### Core Rules

- **ABI 절대 금지**: public/open API 시그니처, 타입, 프로토콜 적합성 변경/삭제 금지. deprecated 전환만 허용.
- **Co-Authored-By 금지**: 커밋 메시지에 절대 추가하지 않는다.
- **Package.swift 수정 금지**: `scripts/Package.swift.template` 편집.
- **`.xcodeproj` 직접 편집 금지**: `project.yml` 또는 `XcodeGen/*.yml` 수정 후 재생성.
- **Config.xcconfig 커밋 금지**: API 키 포함.
- **`[NEXT_VERSION]` 사용**: 새 public API의 `/// - Since:` 태그와 deprecated 어노테이션에 구체적 버전 대신 `[NEXT_VERSION]` 사용. 릴리즈 시점에 일괄 치환.

### Commit Format

```
[TAG] Brief description of change
```

| Tag | Usage |
|-----|-------|
| `[ADD]` | 새 기능/파일 |
| `[MOD]` | 기존 기능 수정 |
| `[FIX]` | 버그 수정 |
| `[REFACTOR]` | 리팩토링 |
| `[RENAME]` | 이름 변경 |
| `[MOVE]` | 파일/코드 이동 |
| `[STYLE]` | 코드 스타일/포맷팅 |
| `[DOCS]` | 문서 |
| `[TEST]` | 테스트 |
| `[CHORE]` | 빌드/CI/의존성 |

### Branch Naming

```
feature/[author]/[feature-name]
feature/[ticket-id]-[description]
hotfix/[description]
release/[version]
```

### Overengineering Prevention

- 요청된 것만 변경. 범위 초과 리팩토링 금지.
- 한 번만 사용되는 로직은 인라인. 조기 추상화 금지.
- 미래 대비 설계, 불필요한 추상화, 사용되지 않을 유틸리티 금지.
- 기존 패턴이 있으면 그것을 따름 (새 패턴 도입 금지).

---

## Project-Specific Rules (auth-ios)

### Access Control

- **접근 제어**: cross-SDK 노출은 `@_spi(SendbirdInternal) public` 사용. `public` 단독 사용 금지
- **공유 가변 상태**: `@InternalAtomic` 또는 `NSLock`/`SafeSerialQueue` 필수
- **외부 의존성 금지**: Apple 프레임워크만 사용. 서드파티 추가 금지

---

### Naming Quick Reference

| 종류 | 규칙 | 예시 |
|------|------|------|
| **Public 타입** | `Auth` 접두사 + PascalCase | `AuthUser`, `AuthError` |
| **내부 타입** | PascalCase (접두사 없음) | `WebSocketManager`, `SessionManager` |
| **Protocol** | `-able`, `-Delegate`, `-DataSource` 접미사 | `ConnectionStatable`, `AuthSessionDelegate` |
| **Boolean** | `is`/`has`/`should` 접두사 | `isConnected`, `hasError` |
| **파일** | `TypeName.swift`, `Type+SendBirdSDK.swift` | `AuthUser.swift`, `String+SendBirdSDK.swift` |

---

### Error Handling

2-tier 시스템:
- **Tier 1**: `AuthClientError: Int, Error` — 내부 에러 코드 enum
- **Tier 2**: `AuthError` — NSError 서브클래스, ObjC 호환, `.asAuthError`로 변환

```swift
let error = AuthClientError.connectionRequired.asAuthError
let error = AuthClientError.invalidParameter.asAuthError(message: .emptyParameter("userId"))
```

---

### Architecture Quick Reference

- **DI**: `Dependency` 프로토콜 + `@DependencyWrapper`. `SendbirdAuthMain`이 유일한 구체 구현
- **연결 상태 머신**: 9개 상태 (`ConnectionStatable` 프로토콜), `SafeSerialQueue`에서만 전환
- **Observer**: `EventDispatcher`(내부 버스) / `EventBroadcaster`(외부 멀티캐스트) / `AsyncEventBroadcaster`(Concurrency 스트림)
- **로깅**: 카테고리 기반 정적 로거 — `Logger.main`, `Logger.session`, `Logger.socket`, `Logger.http`, `Logger.stat` 등

---

### Concurrency

GCD + Swift Concurrency 공존:
- **상태 머신**: `SafeSerialQueue` (GCD)
- **개별 프로퍼티**: `@InternalAtomic`
- **네트워킹**: `actor`, `@globalActor` (Swift Concurrency)
- **공개 API**: completion handler (`@escaping`)
- Read-modify-write는 반드시 `atomicMutate { }` 사용

---

### Anti-patterns

- 서드파티 의존성 추가 (Apple 프레임워크 외 사용)
- 단일 사용 로직을 위한 프로토콜/제네릭/헬퍼 클래스 생성
- 타입별 `CodingKeys` 생성 (`CodeCodingKeys.swift`에 통합)
- 인라인 콜백 시그니처 (`HandlerTypes.swift`에 typealias 정의)
- `Decodable` init에서 `try` 사용 (`try?`로 기본값 대체)
- ABI를 깨는 변경 (public/SPI 시그니처 변경·삭제)
