---
name: iOS CocoaPods Release
description: |
  SendbirdAuthSDK CocoaPods 배포 자동화.
  podspec 생성, 검증, trunk push까지 전체 플로우 수행.

  다음 키워드 요청 시 자동 활성화:
  - "pod 배포", "cocoapods", "pod release"
  - "pod push", "trunk push"
  - "podspec"
---

# CocoaPods Release Flow

SendbirdAuthSDK를 CocoaPods trunk에 배포하는 전체 플로우입니다.

## 실행 전 확인

**스크립트 실행 전 반드시 사용자에게 확인:**

> 테스트 모드로 실행할까요? (실제 배포 없이 검증만 수행)
>
> - **테스트 모드**: `pod lib lint`까지만 실행 (trunk push 안 함)
> - **실제 배포**: 전체 플로우 실행 (trunk push 포함)

## 사전 준비

### 1. CocoaPods trunk 등록 확인

```bash
pod trunk me
```

등록되지 않은 경우:

```bash
pod trunk register your@email.com "Your Name" --description="macbook"
```

### 2. trunk 권한 확인

```bash
pod trunk info SendbirdAuthSDK
```

## 릴리즈 단계

### Step 1: SPM 릴리즈 완료 확인

GitHub Release가 생성되어 xcframework.zip이 업로드되어 있어야 합니다.

```bash
gh release view $VERSION --repo sendbird/sendbird-auth-ios
```

### Step 2: XCFramework 빌드 (필요 시)

`release/SendbirdAuthSDK.zip`이 없으면 빌드:

```bash
python3 script/build_xcframework.py -p SendbirdAuthSDK
```

### Step 3: SHA1 계산

CocoaPods용 zip 파일의 SHA1 계산:

```bash
SHA1=$(shasum release/SendbirdAuthSDK.zip | awk '{print $1}')
echo "SHA1: $SHA1"
```

### Step 4: podspec 생성

```bash
script/generate_podspec.sh -v $VERSION -s $SHA1
```

### Step 5: 로컬 검증용 zip 압축 해제

`pod lib lint`는 로컬 파일을 검사하므로 zip을 풀어야 함:

```bash
unzip -o release/SendbirdAuthSDK.zip -d .
```

### Step 6: podspec 검증

```bash
# 로컬 검증
pod lib lint SendbirdAuthSDK.podspec --allow-warnings

# 원격 검증 (GitHub Release 필요)
pod spec lint SendbirdAuthSDK.podspec --allow-warnings
```

### Step 7: 로컬 검증 폴더 정리

```bash
rm -rf SendbirdAuthSDK
```

### Step 8: trunk push

```bash
pod trunk push SendbirdAuthSDK.podspec --allow-warnings
```

### Step 9: 배포 확인

```bash
pod trunk info SendbirdAuthSDK
```

## 전체 플로우 요약

### 테스트 모드 (검증만)

```bash
VERSION="1.0.0"

# zip 없으면 빌드
[ ! -f release/SendbirdAuthSDK.zip ] && python3 script/build_xcframework.py -p SendbirdAuthSDK

SHA1=$(shasum release/SendbirdAuthSDK.zip | awk '{print $1}')

script/generate_podspec.sh -v $VERSION -s $SHA1

# 로컬 검증용 압축 해제
unzip -o release/SendbirdAuthSDK.zip -d .
pod lib lint SendbirdAuthSDK.podspec --allow-warnings
rm -rf SendbirdAuthSDK

# 여기서 종료 - trunk push 안 함
```

### 실제 배포

```bash
VERSION="1.0.0"

# zip 없으면 빌드
[ ! -f release/SendbirdAuthSDK.zip ] && python3 script/build_xcframework.py -p SendbirdAuthSDK

SHA1=$(shasum release/SendbirdAuthSDK.zip | awk '{print $1}')

script/generate_podspec.sh -v $VERSION -s $SHA1

# 로컬 검증용 압축 해제
unzip -o release/SendbirdAuthSDK.zip -d .
pod lib lint SendbirdAuthSDK.podspec --allow-warnings
rm -rf SendbirdAuthSDK

pod trunk push SendbirdAuthSDK.podspec --allow-warnings
```

## 주의사항

- **SPM 릴리즈 먼저:** GitHub Release 생성 후 pod 배포 진행
- **SHA1 필수:** source의 sha1 값이 정확해야 함
- **LICENSE.md 필요:** xcframework.zip 내에 LICENSE.md 파일 포함 필요
- **버전 중복 불가:** 이미 배포된 버전은 다시 push 불가

## 트러블슈팅

### trunk push 실패 시

```bash
pod cache clean --all
pod trunk push SendbirdAuthSDK.podspec --allow-warnings --verbose
```

### 권한 오류 시

```bash
pod trunk add-owner SendbirdAuthSDK new-owner@email.com
```
