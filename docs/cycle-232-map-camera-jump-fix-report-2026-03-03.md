# Cycle #232 지도 카메라 축척 점프 수정 리포트 (2026-03-03)

- 이슈: #232 `[Bug][Map][UX] 영역 추가 시 카메라 축척 점프 제거(줌/중심 고정)`
- 브랜치: `codex/issue-232-camera-jump-fix`
- 목적: 포인트 추가 시 지도 카메라가 임의로 추적 모드로 전환되어 축척/중심이 점프하는 문제를 제거한다.

## 1. 변경 요약

1. `+` 포인트 추가 버튼에서 `setTrackingMode()` 호출 제거
2. 내 위치 버튼에서만 추적 모드 전환하도록 역할 분리
3. 포인트 추가 전 카메라 스냅샷 저장 + 추가 후 점프 감지 시 복원
4. 지도 카메라 변경 원인 로깅 추가(수동 이동/내 위치 버튼/시스템 fallback)

## 2. 파일 변경

- `dogArea/Views/MapView/MapView.swift`
  - 내 위치 버튼 액션을 `handleLocationButtonTap()`으로 변경
  - `+` 버튼에서 카메라 스냅샷 준비 후 포인트 추가 알림 호출
  - `onMapCameraChange`에서 카메라 변경 이벤트를 ViewModel 로깅 경로로 전달
- `dogArea/Views/MapView/MapViewModel.swift`
  - `CameraChangeReason` 분기 추가
  - `recordCameraChange`, `handleLocationButtonTap`, `preparePointAddCameraSnapshot`, `addLocationPreservingCamera` 구현
  - `setTrackingMode`/`setRegion`에 reason 전달 경로 추가
- `dogArea/Views/MapView/MapSubViews/MapAlertSubView.swift`
  - 포인트 확정 액션을 `addLocationPreservingCamera()`로 교체
- `scripts/map_camera_jump_fix_unit_check.swift`
  - 회귀 방지 정적 검증 스크립트 추가
- `scripts/ios_pr_check.sh`
  - 신규 체크 스크립트를 기본 PR 검증에 연결

## 3. 수용 기준 매핑

1. 포인트 추가 직후 카메라 급격 점프 제거
- `+` 버튼에서 추적 모드 전환 제거 + 카메라 복원 경로 추가로 충족

2. 포인트 추가 시 축척/중심 유지
- 포인트 추가 전 카메라 스냅샷 저장 후 편차 발생 시 즉시 복원

3. `내 위치 보기`에서만 추적 모드 복귀
- 버튼 액션을 전용 핸들러로 분리해 추적 모드 전환 지점을 단일화

4. 연속 추가 상황 회귀 방지
- `map_camera_jump_fix_unit_check` 추가 + `ios_pr_check` 편입

## 4. 검증

1. `swift scripts/map_camera_jump_fix_unit_check.swift`
2. `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh`
3. `bash scripts/ios_pr_check.sh`

참고: 사용자 요청에 따라 디자인 스크린샷 테스트(`run_design_audit_ui_tests.sh`)는 실행하지 않았다.
