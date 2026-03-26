# Feature: CI Re-run Optimization

> 브랜치 `reduce-ci-build-pricing` 작업 시 생성됨 (2026-03-25)

## Current Status
- 상태: 버그 수정 완료
- 마지막 작업: 2026-03-25
- 다음 할 일: CI에서 실제 동작 검증

## Overview

"Re-run failed jobs" 시 **이전에 통과한 테스트를 건너뛰고 실패한 테스트만 재실행**하여 CI 큐 점유 시간과 비용을 줄이는 최적화.

### 메커니즘
1. Attempt 1: 전체 테스트 실행 → 실패 시 **통과한 테스트 목록**을 `actions/cache`에 저장
2. Re-run 감지 (`github.run_attempt > 1`) → 캐시에서 통과 목록 복원
3. `전체 테스트 - 통과 테스트 = 재실행 대상`만 fastlane에 전달
4. 캐시 miss 시 전체 테스트 실행 (fallback)

### 대상 파일
| 파일 | 역할 |
|------|------|
| `run-chat-swift-tests.yml` | Swift 테스트 (matrix: 1-5, chat-local-caching) |
| `run-chat-objc-tests.yml` | ObjC 테스트 (matrix: 1-4) |
| `.github/scripts/extract_tests_ref.py` | xcresult에서 testsRef ID 추출 |
| `.github/scripts/collect_passed_tests.py` | xcresult에서 통과 테스트 이름 수집 |

## Architecture

### 캐시 경로 격리 — 2026-03-25
- **왜**: `actions/cache`는 `path`에 지정된 디렉토리 전체를 저장/복원. 모든 matrix 그룹이 같은 디렉토리를 공유하면, self-hosted 러너에서 순차 실행 시 다른 그룹의 파일이 캐시에 포함되어 오염됨.
- **결정**: 캐시 경로를 matrix 그룹별로 격리
  - Swift: `/tmp/ci-test-cache/<run_id>/swift-<group>/`
  - ObjC: `/tmp/ci-test-cache/<run_id>/objc-<group>/`
- **대안 검토**: 파일 이름만 다르게 하는 방식 (`passed-swift-1.txt`, `passed-swift-2.txt`) → 기각. `actions/cache`가 디렉토리 단위로 동작하므로 근본적으로 해결 안 됨.

### restore-keys fallback — 2026-03-25
- **왜**: 캐시 저장 조건이 `steps.run_tests.outcome != 'success'` (실패 시에만 저장). 중간 attempt에서 성공하면 캐시를 안 남기므로, 이후 attempt에서 직전 캐시를 못 찾아 체인이 끊김. 결과적으로 이미 통과한 테스트를 다시 실행.
- **결정**: `restore-keys`에 prefix fallback 추가. 직전 attempt 캐시가 없으면 같은 그룹의 가장 최근 attempt 캐시를 자동 복원.
  ```yaml
  restore-keys: |
    passed-tests-<run_id>-swift-<group>-attempt
  ```
- **주의사항**: `restore-keys`는 prefix 매칭 후 가장 최근 생성된 캐시를 선택. 누적 merge 로직(`PREV_PASSED + NEW_PASSED`)이 있어 데이터 손실 없음.

### 누적 merge 로직
- **왜**: attempt N에서 일부만 통과하고 일부가 다시 실패할 수 있음. 이전 attempt의 통과 목록과 현재 attempt의 통과 목록을 합쳐야 다음 attempt에서 정확한 재실행 대상을 계산.
- **결정**: `sort -u`로 이전 + 현재 통과 테스트를 중복 제거 합산 후 저장.

## Learnings

### 2026-03-25 — `actions/cache` 디렉토리 단위 동작
- `actions/cache/save`는 `path`의 디렉토리 전체를 하나의 캐시 엔트리로 저장.
- Self-hosted 러너에서 matrix job들이 같은 머신에 순차 배정되면, 공유 디렉토리에 이전 job의 파일이 남아있어 캐시 오염 발생.
- **해결**: matrix 변수를 캐시 경로에 포함시켜 물리적으로 격리.

### 2026-03-25 — 캐시 체인 연속성
- 저장 조건이 "실패 시에만"이면, 성공한 attempt 이후 체인이 끊김.
- `restore-keys` prefix fallback으로 가장 최근 유효한 캐시를 복원하여 해결.

## Solved Problems

### 2026-03-25 — 모든 matrix 그룹이 동일한 재실행 테스트 수를 보고
- **증상**: Re-run 시 job 1, 2, 3 모두 "54 tests remaining (passed=139)" 동일 출력
- **원인**: 캐시 경로 공유로 인한 cross-contamination. 한 그룹의 passed 데이터를 다른 그룹이 참조.
- **수정**: 캐시 경로를 `/tmp/ci-test-cache/<run_id>/<lang>-<group>/`으로 격리.

### 2026-03-25 — Attempt 1 통과 테스트를 이후 attempt에서 재실행
- **증상**: Attempt 4에서 attempt 1에서 이미 통과한 테스트를 다시 실행
- **원인**: 중간 attempt 성공 시 캐시 미저장 → 체인 끊김 → 전체 테스트 재실행
- **수정**: `restore-keys` prefix fallback 추가로 가장 최근 유효 캐시 복원.

## Known Issues
- `chat-local-caching` 그룹은 test subset 파일이 없어 re-run 시에도 전체 실행됨 (의도된 동작)

## Dependencies
- 의존: `actions/cache@v3`, fastlane `test_with_retry`, xcresulttool
- 피의존: `test-with-chat.yml` (orchestrator)
