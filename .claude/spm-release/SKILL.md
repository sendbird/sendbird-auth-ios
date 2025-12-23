---
name: iOS SPM Release (SPM Only)
description: |
  SendbirdAuthSDK SPM(Swift Package Manager) 릴리즈 자동화.
  XCFramework 빌드, GitHub Release 생성, Package.swift binaryTarget 업데이트까지 수행.

  다음 키워드 요청 시 자동 활성화:
  - "SPM 릴리즈", "SPM release", "SPM 배포"
  - "Swift Package Manager 배포"
  - "GitHub Release만", "SPM만"
---

# iOS SDK Release Flow (SPM Only)

SendbirdAuthSDK XCFramework를 GitHub Release로 배포하는 전체 플로우입니다.

---

## 스크립트 구조

SPM 릴리즈는 3개의 phase 스크립트로 분리되어 있습니다:

| 스크립트 | 설명 |
|---------|------|
| `spm_release_phase1.py` | 빌드, Checksum 계산, Private PR 생성 |
| `spm_release_phase2.py` | 태그 생성, 백머지, Public PR 생성 |
| `spm_release_phase3.py` | GitHub Release 생성 |

---

## 실행 방법

### 개별 실행 (단계별)

```bash
# Phase 1: 빌드 및 Private PR 생성
python3 script/spm_release_phase1.py [--mac]

# (Private PR 머지 후)

# Phase 2: 태그, 백머지, Public PR 생성
python3 script/spm_release_phase2.py

# (Public PR 머지 후)

# Phase 3: GitHub Release 생성
python3 script/spm_release_phase3.py
```

### 상태 파일

각 phase 간 상태는 `release/release_state.json`에 저장됩니다:
```json
{
  "version": "X.X.X",
  "branch": "release/X.X.X",
  "project": "SendbirdAuthSDK",
  "checksum_dynamic": "...",
  "checksum_static": "...",
  "private_pr_url": "https://...",
  "public_pr_url": "https://..."
}
```

---

## 배포 대상 Repository

| Repo    | URL                          | 용도                        |
| ------- | ---------------------------- | --------------------------- |
| Public  | `sendbird/sendbird-auth-ios` | SPM 공개 배포 (binaryTarget) |
| Private | `sendbird/auth-ios`          | 내부 개발 (소스 코드 기반)    |

**중요:**
- Private repo의 Package.swift는 **소스 코드 기반으로 유지** (수정하지 않음)
- Public repo에만 binaryTarget Package.swift 사용

---

## Phase 1: 빌드 및 Private PR 생성

`spm_release_phase1.py` 실행:

1. release/X.X.X 브랜치 확인
2. 워킹 디렉토리 클린 확인
3. GitHub CLI 인증 확인
4. Dynamic/Static XCFramework 빌드
5. Checksum 계산
6. 커밋 및 Push
7. Private repo PR 생성

### 출력 파일

```
release/
├─ SendbirdAuthSDK.xcframework/
├─ SendbirdAuthSDK.xcframework.zip
├─ SendbirdAuthSDKStatic.xcframework/
├─ SendbirdAuthSDKStatic.xcframework.zip
└─ release_state.json
```

---

## Phase 2: 태그 및 Public PR 생성

**Private PR 머지 후** `spm_release_phase2.py` 실행:

1. main 브랜치에 태그 생성 및 Push
2. main → develop 백머지
3. Public repo에 Package.swift PR 생성

---

## Phase 3: GitHub Release 생성

**Public PR 머지 후** `spm_release_phase3.py` 실행:

1. Public repo main 브랜치에 태그 생성
2. GitHub Release 생성
3. XCFramework zip 파일 업로드

---

## 주의사항

- **Private repo Package.swift는 수정하지 않음** (소스 코드 기반 유지)
- Public repo에만 binaryTarget Package.swift 사용
- checksum은 반드시 `swift package compute-checksum` 명령어로 계산
- 태그 형식: `X.X.X` (예: 1.0.0, 1.2.3)
- **Private repo**: 릴리즈 후 반드시 main → develop 백머지 수행
- **Public repo**: PR 머지 후에 태그 생성 및 Release 업로드
