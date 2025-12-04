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

## 실행 전 필수 확인 (MANDATORY)

**릴리즈 플로우 시작 전 반드시 사용자에게 확인:**

> 테스트 배포인가요, 실제 배포인가요?
>
> - **테스트 모드**: 빌드 + Checksum 계산까지만 (Step 1-2)
> - **실제 배포**: 전체 플로우 (Step 1-7)

### 테스트 모드일 경우

- Step 1 (XCFramework 빌드): 진행
- Step 2 (Checksum 계산): 진행
- Step 3-7: **스킵** (커밋, PR, 백머지, Release, Package.swift 업데이트 안 함)

### 실제 배포일 경우

- 전체 플로우 진행

---

## 배포 대상 Repository

| Repo    | URL                          | 용도                        |
| ------- | ---------------------------- | --------------------------- |
| Public  | `sendbird/sendbird-auth-ios` | SPM 공개 배포 (binaryTarget) |
| Private | `sendbird/auth-ios`          | 내부 개발 (소스 코드 기반)    |

**중요:**
- Private repo의 Package.swift는 **소스 코드 기반으로 유지** (수정하지 않음)
- Public repo에만 binaryTarget Package.swift 사용

## 릴리즈 전 체크리스트

### 1. 브랜치 확인 및 버전 파싱

현재 브랜치가 `release/X.X.X` 형식인지 확인하고 버전을 파싱합니다.

```bash
BRANCH=$(git branch --show-current)
if [[ ! "$BRANCH" =~ ^release/[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ERROR: 브랜치가 release/X.X.X 형식이 아닙니다. 현재: $BRANCH"
  exit 1
fi
VERSION=${BRANCH#release/}
echo "릴리즈 버전: $VERSION"
```

### 2. 워킹 디렉토리 확인

```bash
git status
```

uncommitted 변경사항이 없어야 합니다.

## 준비 단계: GitHub CLI 인증

### 인증 상태 확인

```bash
gh auth status
```

### 로그인 (토큰 만료 또는 미인증 시)

```bash
gh auth login -h github.com
```

### 필요 권한 확인

```bash
gh repo view sendbird/sendbird-auth-ios --json viewerPermission
gh repo view sendbird/auth-ios --json viewerPermission
```

`"viewerPermission": "WRITE"` 또는 `"ADMIN"`이면 릴리즈 생성 가능.

## 빌드 스크립트

```bash
# Dynamic framework 빌드
python3 script/build_xcframework.py -p SendbirdAuthSDK

# Static framework 빌드
python3 script/build_xcframework.py -p SendbirdAuthSDK --static

# macOS 지원 포함 빌드
python3 script/build_xcframework.py -p SendbirdAuthSDK --mac
```

**릴리즈 시에는 dynamic + static 둘 다 빌드됩니다.**

### 출력 파일

빌드 완료 후 `release/` 디렉토리에 생성:

- `SendbirdAuthSDK.xcframework/` - Dynamic XCFramework
- `SendbirdAuthSDK.xcframework.zip` - Dynamic GitHub Release용
- `SendbirdAuthSDKStatic.xcframework/` - Static XCFramework
- `SendbirdAuthSDKStatic.xcframework.zip` - Static GitHub Release용

## 릴리즈 단계

### Step 1: XCFramework 빌드

```bash
python3 script//build_xcframework.py -p SendbirdAuthSDK
```

### Step 2: Checksum 계산

```bash
CHECKSUM=$(swift package compute-checksum release/SendbirdAuthSDK.xcframework.zip)
echo "Checksum: $CHECKSUM"
```

### Step 3: 커밋 및 Push (Private repo)

**주의: Package.swift는 수정하지 않습니다.**

```bash
git add .
git commit -m "Release $VERSION"
git push origin release/$VERSION
```

### Step 4: Private repo PR 생성 (release → main)

PR 템플릿: `.claude/ios-release/PR_TEMPLATE.md`

```bash
PR_BODY=$(sed "s/\${VERSION}/$VERSION/g; s/\${CHECKSUM}/$CHECKSUM/g" .claude/ios-release/PR_TEMPLATE.md)

gh pr create \
  --repo sendbird/auth-ios \
  --base main \
  --head release/$VERSION \
  --title "Release $VERSION" \
  --body "$PR_BODY"
```

### Step 5: PR 머지 대기 → 머지 확인 → 태그 생성 → 백머지

**PR을 수동으로 머지한 후** 진행합니다. 스크립트가 실제 머지 여부를 확인하고, 머지되지 않았으면 다시 대기합니다.

```bash
# 머지 확인 (스크립트에서 자동 실행)
gh pr view <PR_URL> --json merged --jq '.merged'  # true여야 함

# 태그 생성
git checkout main
git pull origin main
git tag $VERSION
git push origin $VERSION

# main → develop 백머지
git checkout develop
git pull origin develop
git merge main
git push origin develop
```

### Step 6: Public repo Package.swift PR 생성

Public repo에 binaryTarget Package.swift PR 생성:

```bash
# 임시 디렉토리에 public repo 클론
TEMP_DIR=$(mktemp -d)
gh repo clone sendbird/sendbird-auth-ios $TEMP_DIR
cd $TEMP_DIR

# release 브랜치 생성
git checkout -b release/$VERSION

# binaryTarget Package.swift 생성
cat > Package.swift << EOF
// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "SendbirdAuthSDK",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
    ],
    products: [
        .library(
            name: "SendbirdAuthSDK",
            targets: ["SendbirdAuthSDK"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "SendbirdAuthSDK",
            url: "https://github.com/sendbird/sendbird-auth-ios/releases/download/$VERSION/SendbirdAuthSDK.xcframework.zip",
            checksum: "$CHECKSUM"
        ),
    ]
)
EOF

# 커밋 및 push
git add Package.swift
git commit -m "Release $VERSION"
git push origin release/$VERSION

# PR 생성
gh pr create \
  --base main \
  --head release/$VERSION \
  --title "Release $VERSION" \
  --body "Update Package.swift for version $VERSION"

cd -
rm -rf $TEMP_DIR
```

### Step 7: Public repo PR 머지 대기 → 머지 확인 → 태그 & Release 생성

**Public repo PR을 수동으로 머지한 후** 진행합니다. 스크립트가 실제 머지 여부를 확인하고, 머지되지 않았으면 다시 대기합니다.

```bash
# 머지 확인 (스크립트에서 자동 실행)
gh pr view <PR_URL> --json merged --jq '.merged'  # true여야 함

# Public repo에 태그 생성
gh api repos/sendbird/sendbird-auth-ios/git/refs -f ref="refs/tags/$VERSION" -f sha="$(gh api repos/sendbird/sendbird-auth-ios/commits/main --jq '.sha')"

# GitHub Release 생성 (xcframework zip 업로드)
gh release create $VERSION \
  --repo sendbird/sendbird-auth-ios \
  --title "$VERSION" \
  --notes "Release $VERSION" \
  release/SendbirdAuthSDK.xcframework.zip
```

## 주의사항

- **Private repo Package.swift는 수정하지 않음** (소스 코드 기반 유지)
- Public repo에만 binaryTarget Package.swift 사용
- checksum은 반드시 `swift package compute-checksum` 명령어로 계산
- 태그 형식: `X.X.X` (예: 1.0.0, 1.2.3)
- **Private repo**: 릴리즈 후 반드시 main → develop 백머지 수행
- **Public repo**: PR 머지 후에 태그 생성 및 Release 업로드
