# Cycle #70 결과 보고서 (2026-02-26)

## 1. 이슈 확인
- 대상 이슈: `#70 [Task][UX] 권한/오프라인/인증 오류 복구 UX 표준화`

## 2. 개발/문서 반영
- `docs/recovery-ux-standard-v1.md` 추가
  - 권한/오프라인/인증 만료 공통 프레젠터 정책 정의
  - 상태별 원탭 액션(설정 열기/재시도/다시 로그인) 규격화
  - 오프라인 배지 + 온라인 복구 토스트 정책 명시
- `dogArea/Views/GlobalViews/Recovery/RecoveryActionBanner.swift` 추가
  - 공통 복구 배너 컴포넌트
  - `RecoveryIssueKind`, `RecoveryIssueClassifier`, `RecoverySystemAction` 추가
  - Preview snapshot case 3종 추가
- `dogArea/Views/MapView/MapView.swift` 갱신
  - 지도 상단 공통 복구 배너 적용
  - 오프라인 모드 배지 추가
  - 복구 액션 연결:
    - 권한 거부 -> 설정 열기
    - 오프라인 -> 동기화 재시도
    - 인증 만료 -> 재로그인 플로우 진입
- `dogArea/Views/MapView/MapViewModel.swift` 갱신
  - `syncRecoveryToastMessage` 추가
  - 오프라인 대기 -> 온라인 복구 완료 전환 시 토스트 메시지 발행
  - `retrySyncNow()` 원탭 재시도 액션 추가
- `dogArea/Source/UserdefaultSetting.swift` 갱신
  - `AuthFlowCoordinator.startReauthenticationFlow()` 추가
- `dogArea/Views/SigningView/PetProfileSettingView.swift` 갱신
  - 가입 프로필 이미지 업로드 실패 시 공통 복구 배너 적용
- `docs/release-regression-checklist-v1.md` 갱신
  - 권한 복구/오프라인 배지/재로그인/가입 업로드 실패 복구 항목 추가
- `scripts/recovery_ux_unit_check.swift` 추가
  - 복구 UX 핵심 계약 및 스냅샷 Preview 케이스 검증

## 3. 유닛 테스트
- `swift scripts/recovery_ux_unit_check.swift` -> `PASS`
- `swift scripts/release_regression_checklist_unit_check.swift` -> `PASS`
- `swift scripts/guest_upgrade_ux_unit_check.swift` -> `PASS`

## 4. 비고
- UI 스냅샷은 `RecoveryActionBanner` Preview 3종을 회귀 기준으로 고정했다.
