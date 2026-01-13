---
name: iOS Full Release (SPM + CocoaPods)
description: |
  SendbirdAuthSDK 전체 릴리즈 자동화.
  SPM(GitHub Release) + CocoaPods(trunk push) 배포를 순차적으로 수행.

  다음 키워드 요청 시 자동 활성화:
  - "릴리즈", "release", "배포", "deploy"
  - "새 버전", "new version", "버전 업데이트"
  - "SDK 배포", "프레임워크 배포"
  - "전체 배포", "full release"
---

# iOS SDK Full Release Flow (SPM + CocoaPods)

SendbirdAuthSDK를 SPM과 CocoaPods 모두에 배포하는 전체 플로우입니다.

---

## 실행 방법

### 통합 실행 (권장)

```bash
python3 script/full_release.py [--mac]
```

이 스크립트는 모든 phase를 순차 실행하고, PR 머지가 필요한 시점에서 대기합니다:

```
Phase 1: 빌드 및 Private PR 생성
    ↓
Is merged? (y/n) ← Private PR 머지 대기
    ↓
Phase 2: 태그, 백머지, Public PR 생성
    ↓
Is merged? (y/n) ← Public PR 머지 대기
    ↓
Phase 3: GitHub Release 생성
    ↓
Phase 4: CocoaPods 배포
    ↓
완료
```

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

# Phase 4: CocoaPods 배포
python3 script/pod_release.py
```

---

## 스크립트 구조

| 스크립트 | 설명 |
|---------|------|
| `full_release.py` | 전체 플로우 통합 실행 (PR 머지 대기 포함) |
| `spm_release_phase1.py` | 빌드, Checksum 계산, Private PR 생성 |
| `spm_release_phase2.py` | 태그 생성, 백머지, Public PR 생성 |
| `spm_release_phase3.py` | GitHub Release 생성 |
| `pod_release.py` | CocoaPods 배포 |
| `release_common.py` | 공통 유틸리티 모듈 |

---

## 상태 파일

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

## CLI 옵션

### full_release.py

```
--mac              macOS 빌드 포함
--project          프로젝트 이름 (기본: SendbirdAuthSDK)
--private-repo     Private repo (기본: sendbird/auth-ios)
--public-repo      Public repo (기본: sendbird/sendbird-auth-ios)
--build-if-missing CocoaPods용 zip 없을 시 자동 빌드
```

---

## 배포 순서 상세

### Phase 1: SPM Release (빌드 ~ Private PR)

1. release/X.X.X 브랜치 확인
2. 워킹 디렉토리 클린 확인
3. GitHub CLI 인증 확인
4. Dynamic/Static XCFramework 빌드
5. Checksum 계산
6. 커밋 및 Push
7. Private repo PR 생성

### Phase 2: SPM Release (태그 ~ Public PR)

1. main 브랜치에 태그 생성 및 Push
2. main → develop 백머지
3. Public repo에 Package.swift PR 생성

### Phase 3: SPM Release (GitHub Release)

1. Public repo main 브랜치에 태그 생성
2. GitHub Release 생성
3. XCFramework zip 파일 업로드

### Phase 4: CocoaPods Release

1. SPM Release 확인
2. SHA1 계산
3. podspec 생성
4. lint 검증
5. trunk push

---

## 주의사항

- **순서 준수:** 각 Phase는 이전 Phase 완료 후 진행
- **PR 머지 확인:** 스크립트가 자동으로 머지 여부 확인
- **Private repo Package.swift는 수정하지 않음** (소스 코드 기반 유지)
