# Cycle 141 Report — Map Motion Pack v1 (2026-02-27)

## 1. 대상
- Issue: `#141 [Task][UI Motion][Map] 점령 피드백 모션팩 v1`
- Branch: `codex/cycle-141-map-motion-pack`

## 2. 구현 요약
- 타일 점령 파동 애니메이션 추가
  - 포인트 기록 시 지도 좌표에 원형 확산 + 페이드 렌더링
  - 기본 0.52s, 축소 모션 0.35s
- 산책 중 발바닥 트레일 추가
  - 최근 5초 포인트를 잔상 형태로 표시
  - 최대 12개 제한
- 클러스터 분해/결합 모션 추가
  - 줌에 따른 클러스터 count 변화 감지 후 pulse 모션 반영
- 날씨 오버레이 전환 추가
  - `weather.risk.level.v1` 값 기반 틴트 오버레이 크로스페이드
- 지도 인터랙션 햅틱 연동
  - 점령 성공(light impact), 경고(warning notification)
  - 과도 반복 방지 throttle 적용
- 저성능/접근성 대응
  - `모션 축소` 토글 추가(`map.motion.reduced`)
  - 시스템 Reduce Motion과 결합 적용

## 3. 변경 파일
- `dogArea/Views/MapView/MapView.swift`
- `dogArea/Views/MapView/MapSubViews/MapSubView.swift`
- `dogArea/Views/MapView/MapSubViews/MapSettingView.swift`
- `dogArea/Views/MapView/MapViewModel.swift`
- `docs/map-motion-pack-v1.md`
- `docs/cycle-141-map-motion-pack-report-2026-02-27.md`
- `scripts/map_motion_pack_unit_check.swift`
- `scripts/ios_pr_check.sh`

## 4. 검증
- `swift scripts/map_motion_pack_unit_check.swift` -> PASS
- `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh` -> PASS

## 5. 리스크/후속
- 날씨 오버레이는 현재 UserDefaults 기반이라 실시간 외부 날씨 API 동기화와는 분리되어 있다.
- 클러스터 전환 모션은 count 기반 pulse v1이며, 다음 단계에서 개별 클러스터 매칭 기반 transform으로 확장 가능하다.
