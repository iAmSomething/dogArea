# Cycle 158 - Apple 로그인 임시 비활성화 (Email only) (2026-03-01)

## 목적
- Apple Developer signing 준비 전까지 인증 진입을 이메일 로그인/회원가입으로 단순화.
- Sign in with Apple entitlement로 인한 서명 충돌 가능성을 제거.

## 변경 사항
1. SignIn 화면 정책 변경
- `SignInView`에 `isAppleSignInTemporarilyDisabled` 플래그 추가 (기본값 `true`).
- 기본 UX는 이메일 로그인/회원가입만 노출.
- Apple 로그인은 준비 중 안내 문구로 대체.

2. 타입 정합성 수정
- `SigningViewModel`의 입력 타입을 `AppleUserInfo` -> `AuthUserInfo`로 교체.

3. Entitlement 정리
- Debug/Release entitlements에서 `com.apple.developer.applesignin` 제거.

## 파일
- `dogArea/Views/SigningView/SignInView.swift`
- `dogArea/Views/SigningView/SigningViewModel.swift`
- `dogArea/dogAreaDebug.entitlements`
- `dogArea/dogAreaRelease.entitlements`

## 검증
- `bash scripts/ios_pr_check.sh` 실행
  - 문서/정적 유닛 체크: PASS
  - iOS 빌드: PASS
  - watchOS 빌드: PASS

## 롤백 방법
- `SignInView` 생성 시 `isAppleSignInTemporarilyDisabled: false`로 주입.
- entitlements에 `com.apple.developer.applesignin` 키 재추가.
