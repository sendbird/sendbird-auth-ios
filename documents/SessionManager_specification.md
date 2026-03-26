# SessionManager Specification

## 개요

공유 `SessionManager`는 여러 SDK 간 세션을 저장하고 조정하는 코어입니다.
세션 만료 시 한 `SessionRuntime`이 갱신한 세션을 다른 runtime들과 공유합니다.

---

## 메서드 스펙

### `requestSessionRefresh(for: Session) -> Bool`

| 항목          | 내용                                     |
| ------------- | ---------------------------------------- |
| **호출 시점** | API 응답이 401일 때                      |
| **파라미터**  | `current` - 현재 SDK가 보유한 세션       |
| **반환값**    | 갱신 가능한 observer가 있으면 `true`, 없으면 `false` |

**동작**:

```
for observer in observers where observer.canRefreshSession:
    observer.sessionRefreshRequested(for: current)
return observers.contains(where: \.canRefreshSession)
```

**호출자 후속 처리**:
| 반환값 | 처리 |
|--------|------|
| `true` | `sessionDidChange` 또는 `sessionRefreshFailed` 콜백 대기 |
| `false` | 즉시 refresh failure 처리 |

---

### `submitRefreshedSession(_ newSession: Session) -> Bool`

| 항목          | 내용                                       |
| ------------- | ------------------------------------------ |
| **호출 시점** | 토큰 갱신 API 응답 받았을 때               |
| **파라미터**  | `newSession` - 갱신 API로 받은 새 세션     |
| **반환값**    | `true` - 채택됨, `false` - 거부됨 (이미 사용된 키) |

**동작**:

```
if newSession.key in knownKeys:
    return false  // 이미 사용된 키 → 롤백 방지
else:
    knownKeys.insert(newSession.key)
    저장된 세션 = newSession
    onSessionChanged 콜백 호출
    return true
```

---

## 세션 식별 기준

```
새 세션 채택 여부  ⟺  newSession.key not in knownKeys
```

> **knownKeys**: 이미 사용된 세션 키를 추적하는 Set. 이전 키로의 롤백을 방지합니다.

---

## 콜백 규칙

### `onSessionChanged(handler: (Session?) -> Void)`

| 항목          | 내용                          |
| ------------- | ----------------------------- |
| **호출 시점** | SDK 초기화 시                 |
| **용도**      | 세션 변경 알림 수신 |

**콜백 발생 조건**:
| 트리거 | 콜백 호출 |
|--------|-----------|
| `setSession` 호출 | ✅ 호출 |
| `submitRefreshedSession`에서 새 세션 채택됨 | ✅ 호출 |
| `submitRefreshedSession`에서 기존 세션 유지됨 | ❌ 호출 안 함 |

---

## 시나리오

### 시나리오 1: 동시 401 발생

```mermaid
sequenceDiagram
    participant Chat as Chat SDK
    participant Desk as Desk SDK
    participant Manager as Shared SessionManager
    participant API as API Server

    Note over Chat,Desk: 초기화 시 콜백 등록
    Chat->>Manager: addSessionObserver(runtime)
    Desk->>Manager: addSessionObserver(runtime)

    Note over Chat,API: 두 SDK가 동시에 401 받음

    Desk->>Manager: requestSessionRefresh(v1)
    Manager--)Chat: sessionRefreshRequested(v1)

    Chat->>API: 토큰 갱신
    API-->>Chat: session (v2)

    Chat->>Manager: submitRefreshedSession(v2)

    Manager--)Chat: sessionDidChange(v2)
    Manager--)Desk: sessionDidChange(v2)

    Note over Chat,Desk: 두 SDK 모두 v2 세션 사용
```

---

### 시나리오 2: 이미 갱신된 세션이 있는 경우

```mermaid
sequenceDiagram
    participant Desk as Desk SDK
    participant Manager as Shared SessionManager
    participant API as API Server

    Note over Manager: 현재 저장된 세션: v2

    Note over Desk: Desk가 오래된 v1으로 401 받음
    Desk->>Manager: hasRefreshedSession(v1)
    Manager-->>Desk: true

    Note over Desk: 갱신 불필요, 바로 v2 사용
    Desk->>API: API 재요청 (with v2)
    API-->>Desk: 200 OK
```

---

## 컴포넌트 구조

```mermaid
classDiagram
    class SessionManager {
        +setSession(session: Session?)
        +loadSession() Session?
        +requestSessionRefresh(current: Session) Bool
        +submitRefreshedSession(newSession: Session) Bool
        +addSessionObserver(observer)
    }

    class SessionRuntime {
        +sessionDidChange(session: Session?)
        +sessionRefreshRequested(session: Session)
    }

    class SessionManagerRegistry {
        +sessionManager(applicationId: String, userId: String) SessionManager
    }

    class SessionManagerStore {
        -cachedSession: Session?
        -knownKeys: Set~String~
        -queue: SafeSerialQueue
    }

    class Session {
        +key: String
        +services: [Service]
        +isDirty: Bool
    }

    SessionManager --> SessionManagerStore
    SessionRuntime --> SessionManager
    SessionManagerRegistry --> SessionManager
```

---

## 상태 다이어그램

```mermaid
stateDiagram-v2
    [*] --> NoSession: 초기 상태

    NoSession --> HasSession: setSession(session)
    NoSession --> HasSession: loadSession() 성공

    HasSession --> HasSession: submitRefreshedSession()
    HasSession --> NoSession: setSession(nil)

    state HasSession {
        [*] --> Valid
        Valid --> Expired: API 401
        Expired --> Valid: hasRefreshedSession() == true
        Expired --> Valid: sessionDidChange 콜백
    }
```
