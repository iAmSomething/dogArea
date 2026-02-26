# FeatureGate Architecture v1 (Issue #75)

## 목적
- 세션 상태를 `guest` / `member` 2상태로 고정한다.
- 기능 접근 판정을 단일 매트릭스(`AppFeatureGate`)로 통합한다.
- 권한 미충족을 에러 대신 업그레이드 제안 UX로 처리한다.

## 세션 모델
- `AppSessionState.guest`
- `AppSessionState.member(userId)`

현재 세션은 `UserdefaultSetting.shared.getValue()?.id` 기반으로 산출한다.

## 기능 정책 매트릭스
- `walkRead` -> guest 허용
- `walkWrite` -> guest 허용
- `cloudSync` -> member 전용 (`walkHistory` 트리거)
- `aiGeneration` -> member 전용 (`imageGenerator` 트리거)
- `nearbySocial` -> member 전용 (`walkHistory` 트리거)

## 적용 방식
1. UI 계층
- 뷰에서 직접 `if userId != nil`로 분기하지 않고
  `AuthFlowCoordinator.requestAccess(feature:)` 사용
- 차단 시 자동으로 공통 업그레이드 시트(`MemberUpgradeSheetView`) 노출

2. API 계층
- `SupabaseSyncOutboxTransport.send`에서 `cloudSync` 권한 가드 적용
- 권한 미충족 상태에서는 네트워크 요청을 보내지 않고 즉시 반환

3. 핵심 UX 보장
- 게스트도 산책 시작/종료/목록 조회는 그대로 사용 가능
- 회원 전용 기능만 업그레이드 유도

## 반영 파일
- `dogArea/Source/UserdefaultSetting.swift`
- `dogArea/Views/MapView/MapSubViews/StartButtonView.swift`
- `dogArea/Views/ImageGeneratorView/TextToImageView.swift`
- `dogArea/Views/ImageGeneratorView/ImageGenerateViewModel.swift`
- `dogArea/Views/WalkListView/WalkListView.swift`
- `dogArea/Views/MapView/MapView.swift`
- `dogArea/Views/MapView/MapViewModel.swift`

## QA 체크
- [ ] 게스트로 산책 시작/종료/목록 조회 정상 동작
- [ ] 게스트 상태 이미지 생성 시 업그레이드 시트/차단 메시지 일관 동작
- [ ] 게스트 상태 cloud sync API 호출 미발생
- [ ] 로그인 후 재시작 없이 member 전용 기능 즉시 사용 가능
