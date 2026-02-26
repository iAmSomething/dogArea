# Guest to Member Upgrade UX v1

## Scope
- Issue: #77
- Goal: 비회원(게스트) 사용 중 회원 전환 UX를 공통화하고, 로그인 후 원래 화면으로 복귀시키는 흐름을 고정한다.

## Implemented Behavior
1. 앱 첫 진입 분기
- `바로 시작`: 게스트 모드로 진입
- `로그인하고 동기화`: 즉시 로그인 플로우 진입

2. 공통 잠금 UX
- 회원 전용 동작에서 동일한 바텀시트(`MemberUpgradeSheetView`) 노출
- 메시지/버튼 카피를 공통으로 사용
- `나중에` 선택 시 현재 화면 유지

3. 로그인 후 복귀
- 기존 `RootView` 재생성(fullScreenCover) 제거
- 콜백 기반(`onAuthenticated`)으로 현재 컨텍스트 복귀

4. 적용 지점
- 산책 시작 버튼은 게스트 허용(FeatureGate `walkWrite`)으로 전환
- 텍스트-이미지 생성(`image_generator`)
- 산책 목록 동기화 유도(`walk_history`)
- 지도 상 백업 유도 배너(`walk_backup`)

## State Contract
- `AuthFlowCoordinator`
  - `shouldShowEntryChoice`
  - `shouldShowSignIn`
  - `pendingUpgradeRequest`
  - `isGuestMode`
- persisted keys
  - `auth.guest_mode.v1`
  - `auth.entry_choice_completed.v1`

## QA Checklist
- [ ] 첫 실행에서 진입 선택 시트가 1회 노출되는가
- [ ] 게스트로 시작 후 회원 전용 액션에서 공통 시트가 뜨는가
- [ ] 로그인 성공 시 기존 화면 컨텍스트가 유지되는가
- [ ] `나중에` 선택 시 강제 이동/앱 종료가 없는가
- [ ] 지도/목록/이미지 생성 진입에서 카피가 일관적인가
