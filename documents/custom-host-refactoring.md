# Custom Host 리팩토링

## 개요

Custom host 관리를 UserDefaults(pref)에서 메모리(routerConfig)로 변경한 리팩토링 내용입니다.

## 문제점

- Custom host 설정이 UserDefaults에 영속 저장됨
- Custom host를 제거해도 init 시 다시 pref에 저장되어 적용되지 않음
- chat-ios와 auth-ios 양쪽에서 pref를 관리하여 이중 관리 문제 발생

## 해결 방안

- Custom host의 pref 저장 로직 제거
- `CommandRouterConfiguration` (메모리)을 단일 진실 공급원으로 사용
- Custom host는 init 파라미터 또는 `setCustomHost()` API로만 설정

## 변경된 파일

### Configuration.swift

- `apiHostURL(for:customHost:)`: `customHost` 파라미터 추가, pref 조회 제거
- `wsHostURL(for:customHost:)`: `customHost` 파라미터 추가, pref 조회 제거
- `setCustomHost(_:)`: pref 저장 → `routerConfig.updateHost()` 호출로 변경, **deprecated**
- `CustomHostEnvironment`: **deprecated** (updateCustomHost 사용 권장)
- `clearCustomHost()`: pref 삭제 → 기본 host로 `routerConfig.updateHost()` 호출로 변경
- `updateCustomHost(apiHost:wsHost:)`: **신규 SPI** - init 이후 동적으로 host 변경 (connected 상태면 abort)

### SendbirdAuthMain.swift

- **신규 property 추가**:
  - `defaultApiHost`, `defaultWsHost`: init 시 계산된 기본 host (불변)
  - `currentApiHost`, `currentWsHost`: 현재 설정된 host 추적
- `init()`: pref 저장 제거, 기본/현재 host property 초기화
- `private connect()`: nil이면 기본값 사용, 값 변경 시에만 routerConfig 업데이트
- `private authenticate()`: nil이면 기본값 사용, 값 변경 시에만 routerConfig 업데이트

## API 변경사항

Public API 변경 없음. 내부 구현만 변경.

| API | 변경 전 | 변경 후 |
|-----|--------|--------|
| `setCustomHost(_:)` | pref에 저장 | routerConfig 업데이트 |
| `clearCustomHost()` | pref에서 삭제 | routerConfig를 기본값으로 업데이트 |
| `connect(apiHost:wsHost:)` | pref 저장 + routerConfig 업데이트 | routerConfig만 업데이트 |
| `authenticate(apiHost:)` | pref 저장 + routerConfig 업데이트 | routerConfig만 업데이트 |

## 하위 호환성

- 기존 pref 데이터는 무시됨 (마이그레이션 불필요)
- API 인터페이스 변경 없음
- 심볼 호환성 유지
