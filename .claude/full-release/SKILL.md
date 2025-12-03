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

## 실행 전 필수 확인 (MANDATORY)

**릴리즈 플로우 시작 전 반드시 사용자에게 확인:**

> 테스트 배포인가요, 실제 배포인가요?
>
> - **테스트 모드**: SPM 빌드만 + CocoaPods 검증만
> - **실제 배포**: SPM 전체 + CocoaPods 전체

---

## 배포 순서

```
1. Phase 1: SPM Release
   → .claude/spm-release/SKILL.md 참조

2. Phase 2: CocoaPods Release
   → .claude/pod-release/SKILL.md 참조
```

---

## Phase 1: SPM Release

**`.claude/spm-release/SKILL.md`** 를 따릅니다.

### 테스트 모드

- Step 1-2까지만 진행 (빌드 + Checksum 계산)
- Step 3-7 스킵 (커밋, PR, Release 안 함)

### 실제 배포

- 전체 플로우 진행

---

## Phase 2: CocoaPods Release

**`.claude/pod-release/SKILL.md`** 를 따릅니다.

### 테스트 모드

- Step 6 (`pod lib lint`)까지만 진행
- `pod trunk push` 스킵

### 실제 배포

- 전체 플로우 진행 (`pod trunk push` 포함)

---

## 주의사항

- **순서 준수:** Phase 1 (SPM) 완료 후 Phase 2 (CocoaPods) 진행
- **테스트/실제 배포 확인 필수:** 플로우 시작 전 반드시 사용자에게 확인
