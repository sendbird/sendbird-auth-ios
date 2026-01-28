---
name: iOS Release Workflow (GitHub Actions)
description: |
  SendbirdAuthSDK 자동 릴리즈 워크플로우 (GitHub Actions).
  release 브랜치 PR 생성 후 workflow_dispatch로 트리거하면
  전체 배포 프로세스가 자동으로 실행됩니다.

  다음 키워드 요청 시 자동 활성화:
  - "GitHub Actions 릴리즈", "워크플로우 실행"
  - "자동 배포", "automated release"
---

# iOS SDK Release Workflow (GitHub Actions)

SendbirdAuthSDK를 GitHub Actions를 통해 자동으로 배포하는 워크플로우입니다.
기존 Python 스크립트 (`full_release.py`)와 동일한 결과물을 생성합니다.

---

## 릴리즈 플로우

```
1. release/X.X.X 브랜치 생성
2. CHANGELOG_DRAFT.md 작성
3. PR 생성 (release/X.X.X → main)
4. GitHub Actions에서 release-workflow 트리거
5. [자동] 환경 설정 → PR 머지 → 빌드 → 배포 → 알림
```

---

## 워크플로우 실행 방법

### GitHub UI에서 실행

1. GitHub Repository → Actions → Release 선택
2. "Run workflow" 클릭
3. 옵션 설정:
   - `xcode_version`: Xcode 버전 (기본: 16.2)
   - `release_ticket_key`: Jira 티켓 키 (선택사항)
   - `is_test`: 테스트 모드 (true 시 실제 배포 스킵)
4. "Run workflow" 실행

### 테스트 모드

`is_test: true`로 설정하면 실제 배포 없이 전체 플로우를 검증할 수 있습니다:
- PR 머지 스킵
- GitHub Release 생성 스킵
- CocoaPods 배포 스킵
- Slack 알림 스킵

---

## 워크플로우 구성

### Composite Actions

| 액션 | 설명 |
|------|------|
| `0-setup` | Xcode 선택, SSH 설정, brew 패키지 설치, 버전 추출 |
| `1-manage-private-repo` | release→main PR 머지, main→develop 백머지, 태그 생성 |
| `2-build-sdk` | Dynamic/Static XCFramework 빌드, checksum 계산 |
| `3-manage-public-repo` | Public repo PR 생성/머지, Package.swift/podspec 생성 |
| `4-release-distribution` | GitHub Release 생성, CocoaPods trunk push |
| `5-notifications` | Slack 알림, Jira 티켓 상태 전환 |

### 파일 구조

```
.github/
├── workflows/
│   └── release-workflow.yml         # 메인 워크플로우
└── composite-actions/
    └── release/
        ├── 0-setup/action.yml
        ├── 1-manage-private-repo/action.yml
        ├── 2-build-sdk/action.yml
        ├── 3-manage-public-repo/action.yml
        ├── 4-release-distribution/action.yml
        └── 5-notifications/action.yml

scripts/
└── generate_package.sh              # Package.swift 생성 스크립트

script/
├── build_xcframework.py             # XCFramework 빌드 (기존)
└── generate_podspec.sh              # Podspec 생성 (기존)

Brewfile                             # brew 의존성
CHANGELOG_DRAFT.md                   # 릴리즈 노트 템플릿
```

---

## 빌드 산출물

GitHub Actions와 Python 스크립트 모두 동일한 산출물 생성:

| 파일 | 용도 | Package.swift |
|------|------|---------------|
| `SendbirdAuthSDK.xcframework.zip` | SPM Dynamic | `SendbirdAuthSDK` target |
| `SendbirdAuthSDKStatic.xcframework.zip` | SPM Static | `SendbirdAuthSDKStatic` target |
| `SendbirdAuthSDK.zip` | CocoaPods | - |

### Package.swift 구조

```swift
// Dynamic + Static 둘 다 포함 (Python과 동일)
products: [
    .library(name: "SendbirdAuthSDK", targets: ["SendbirdAuthSDK"]),
    .library(name: "SendbirdAuthSDKStatic", targets: ["SendbirdAuthSDKStatic"]),
],
targets: [
    .binaryTarget(name: "SendbirdAuthSDK", url: "...dynamic...", checksum: "..."),
    .binaryTarget(name: "SendbirdAuthSDKStatic", url: "...static...", checksum: "..."),
]
```

---

## Python 스크립트와의 비교

| 항목 | Python (로컬) | GitHub Actions |
|------|--------------|----------------|
| PR 머지 | 수동 대기 (`y/n` 입력) | 자동 승인/머지 |
| 상태 관리 | `release_state.json` | GitHub outputs |
| 알림 | 없음 | Slack + Jira |
| Package.swift | Dynamic + Static | Dynamic + Static (동일) |
| Checksum | SHA256 (SPM) + SHA1 (CocoaPods) | 동일 |

---

## 필요한 GitHub Secrets

| Secret | 용도 |
|--------|------|
| `SSH_KEY` | Private repo 접근 |
| `GH_API_TOKEN` | GitHub API |
| `GH_TOKEN_FOR_PR_APPROVAL` | PR 자동 승인 |
| `COCOAPODS_TRUNK_TOKEN` | CocoaPods 배포 |
| `SLACK_BOT_TOKEN` | Slack 알림 |
| `SLACK_RELEASE_CHANNEL_ID` | 릴리즈 채널 |
| `SLACK_RELEASE_APPROVER_CHANNEL_ID` | 승인자 채널 |
| `JIRA_AUTH_USER` | Jira 사용자 |
| `JIRA_AUTH_API_TOKEN` | Jira API |

---

## 기존 로컬 스크립트와의 관계

기존 `script/` 폴더의 스크립트들은 로컬 실행 백업용으로 유지됩니다:

- `script/build_xcframework.py` - GitHub Actions에서도 사용
- `script/generate_podspec.sh` - GitHub Actions에서도 사용
- `script/full_release.py` - 로컬 실행용
- `script/spm_release/` - 로컬 실행용
- `script/pod_release.py` - 로컬 실행용

---

## 주의사항

- **브랜치 네이밍:** `release/X.X.X` 형식 준수
- **CHANGELOG_DRAFT.md:** 릴리즈 전 반드시 작성
- **테스트 모드 활용:** 첫 배포 전 `is_test: true`로 검증
- **Secrets 확인:** 모든 필수 secrets 설정 확인
