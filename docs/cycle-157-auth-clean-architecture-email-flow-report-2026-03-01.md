# Cycle 157 - Auth 클린 아키텍처 분리 + Email 로그인/회원가입 플로우 정리 (2026-03-01)

## 목적
- SignIn 화면의 인증 분기(Apple/Email)를 Presentation 레이어에서 직접 처리하지 않고 UseCase로 단일화.
- 인증 관련 의존성을 protocol/service 단위로 분리해 테스트 가능성과 교체 가능성을 높임.

## 변경 사항
1. 인증 도메인 타입/계약 추가
- `AuthRequest`
- `AuthUseCaseOutcome`
- `AuthenticatedUserIdentity`

2. 인증 레이어 분리
- `AuthSessionStoreProtocol` / `DefaultAuthSessionStore`
- `AuthRepositoryProtocol` / `DefaultAuthRepository`
- `AuthUseCaseProtocol` / `DefaultAuthUseCase`

3. SignIn 화면 구조 변경
- `SignInView`가 `AuthUseCaseProtocol`에만 의존하도록 전환.
- Apple 로그인과 Email 로그인/회원가입이 동일한 유즈케이스 결과(`AuthUseCaseOutcome`)를 사용.
- 결과 처리 분기를 `applyAuthOutcome` 단일 함수로 통합.

4. 인프라 어댑터 유지
- `DeviceAppleCredentialAuthService`는 `AppleCredentialAuthServiceProtocol` 구현체로 유지.
- Email 로그인/회원가입은 Supabase Auth REST를 통해 처리.

## 파일
- `dogArea/Source/ProfileRepository.swift`
- `dogArea/Views/SigningView/SignInView.swift`

## 검증
- `bash scripts/ios_pr_check.sh`
  - 문서/정적 유닛 체크: PASS
  - iOS build: PASS
  - watchOS build: PASS

## 남은 작업
- Apple OAuth 완전 연동(client id/secret 포함) 시 `signInWithApple` 최소검증 로직을 Supabase OAuth 교환 플로우로 교체.
- Auth 레이어를 `Source/Auth/*`로 파일 분리(현재는 전환 속도 우선으로 `ProfileRepository.swift`에 공존).
