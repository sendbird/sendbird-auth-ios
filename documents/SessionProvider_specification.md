# SessionProvider Specification

## 개요

SessionProvider는 여러 SDK 간 세션을 공유하고 관리하는 컴포넌트입니다.
세션 만료 시 한 SDK가 갱신한 세션을 다른 SDK들과 공유합니다.

---

## 메서드 스펙

### `requestRefresh(current: Session) -> Session?`

| 항목          | 내용                                     |
| ------------- | ---------------------------------------- |
| **호출 시점** | API 응답이 401일 때                      |
| **파라미터**  | `current` - 현재 SDK가 보유한 세션       |
| **반환값**    | 더 최신 세션이 있으면 반환, 없으면 `nil` |

**동작**:

```
if 저장된 세션.key != current.key:
    return 저장된 세션  // 이미 다른 SDK가 갱신함
else:
    return nil  // 갱신 필요
```

**호출자 후속 처리**:
| 반환값 | 처리 |
|--------|------|
| `Session` | 해당 세션으로 API 재요청 |
| `nil` | 토큰 갱신 진행 (갱신 로직 있는 SDK만) 또는 `onSessionChanged` 콜백 대기 |

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
    participant Provider as SessionProvider
    participant API as API Server

    Note over Chat,Desk: 초기화 시 콜백 등록
    Chat->>Provider: onSessionChanged(handler)
    Desk->>Provider: onSessionChanged(handler)

    Note over Chat,API: 두 SDK가 동시에 401 받음

    Chat->>Provider: requestRefresh(v1)
    Provider-->>Chat: nil (갱신 필요)

    Desk->>Provider: requestRefresh(v1)
    Provider-->>Desk: nil (갱신 필요)

    Note over Chat: 갱신 로직 구현됨
    Note over Desk: 갱신 로직 없음 (콜백 대기)

    Chat->>API: 토큰 갱신
    API-->>Chat: session (v2)

    Chat->>Provider: submitRefreshedSession(v2)

    Provider--)Chat: onSessionChanged(v2)
    Provider--)Desk: onSessionChanged(v2)

    Note over Chat,Desk: 두 SDK 모두 v2 세션 사용
```

---

### 시나리오 2: 이미 갱신된 세션이 있는 경우

```mermaid
sequenceDiagram
    participant Desk as Desk SDK
    participant Provider as SessionProvider
    participant API as API Server

    Note over Provider: 현재 저장된 세션: v2

    Note over Desk: Desk가 오래된 v1으로 401 받음
    Desk->>Provider: requestRefresh(v1)
    Provider-->>Desk: v2 반환

    Note over Desk: 갱신 불필요, 바로 v2 사용
    Desk->>API: API 재요청 (with v2)
    API-->>Desk: 200 OK
```

---

## 컴포넌트 구조

```mermaid
classDiagram
    class SessionProvider {
        <<protocol>>
        +setSession(session: Session?, userId: String)
        +loadSession(userId: String) Session?
        +requestRefresh(current: Session) Session?
        +submitRefreshedSession(newSession: Session) Bool
        +onSessionChanged(handler)
    }

    class PersistentSessionProvider {
        -session: Session?
        -knownKeys: Set~String~
        -userId: String?
        -handlers: [Handler]
        -queue: SafeSerialQueue
        +shared: PersistentSessionProvider
    }

    class Session {
        +key: String
        +services: [Service]
        +isDirty: Bool
    }

    SessionProvider <|.. PersistentSessionProvider
    PersistentSessionProvider --> Session
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
        Expired --> Valid: requestRefresh() → Session
        Expired --> Valid: onSessionChanged 콜백
    }
```
