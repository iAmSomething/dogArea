# Swift Stability Hardening v1

## 1. 목표
- 강제 언래핑(`!`, `try!`) 기반 잠재 크래시 경로를 줄인다.
- modal 카운트다운 타이머의 수명 주기를 명확히 관리한다.

## 2. 적용 범위
- `SignInView` Apple 로그인 토큰 처리
- `StartModalView` 카운트다운 timer
- 기타 force unwrap 빈발 지점의 안전화

## 3. 구현 원칙
- 외부 입력(Apple credential, UserDefaults decode, CoreData 변환)은 `guard`/`if let`/`compactMap`으로 처리한다.
- Timer는 `onAppear` 생성, `onDisappear` 무효화, 종료 시점 정리를 보장한다.

## 4. 완료 기준
- identityToken/authorizationCode 강제 언래핑 제거
- StartModalView 타이머 무효화 + dismiss 흐름 정상화
- 주요 force unwrap 지점 정리 후 기존 동작 회귀 없음
