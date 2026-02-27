# Cycle 150 Report — Rival Privacy Hard Guard (2026-02-27)

## 1. 대상
- Issue: `#150 [P0][Task] 라이벌 프라이버시 하드 가드(k-anon + 야간 지연)`
- Branch: `codex/cycle-150-rival-privacy`

## 2. 구현 요약
- Supabase에 프라이버시 가드 정책 테이블(`privacy_guard_policies`)을 추가하고 기본 정책(`k=20`, 주간 30분/야간 60분, 퍼센타일 fallback)을 고정
- `rpc_get_nearby_hotspots`를 지연 반영 + k-anon + 민감 구역 마스킹 규칙으로 재구현
- 표본 미달 셀은 `count=0`으로 비공개 처리하고 `percentile_only` 모드 intensity만 반환
- 민감 구역 정의 테이블(`privacy_sensitive_geo_masks`)과 자동 마스킹 판별 함수 추가
- `privacy_guard_audit_logs` + `view_privacy_guard_alerts_24h`로 요청 단위 점검 로그/경보 경로 추가
- Edge Function(`nearby-presence`)에서 suppression 메타데이터를 파싱해 audit log를 적재하도록 확장

## 3. 변경 파일
- `supabase/migrations/20260227192000_rival_privacy_hard_guard.sql`
- `supabase/functions/nearby-presence/index.ts`
- `dogArea/Views/MapView/MapViewModel.swift`
- `docs/nearby-anonymous-hotspot-v1.md`
- `docs/rival-privacy-hard-guard-v1.md`
- `docs/release-regression-checklist-v1.md`
- `README.md`
- `scripts/nearby_hotspot_unit_check.swift`
- `scripts/rival_privacy_hard_guard_unit_check.swift`
- `scripts/release_regression_checklist_unit_check.swift`
- `scripts/ios_pr_check.sh`

## 4. 유닛 체크
- `swift scripts/nearby_hotspot_unit_check.swift` -> PASS
- `swift scripts/rival_privacy_hard_guard_unit_check.swift` -> PASS
- `swift scripts/release_regression_checklist_unit_check.swift` -> PASS
- `swift scripts/project_stability_unit_check.swift` -> PASS

## 5. 리스크/후속
- 라이벌 전용 리더보드/매칭 백엔드(Stage 2, #131)가 아직 미구현이라 현재 가드는 nearby 경로에 선적용 상태.
- 운영 단계에서 `privacy_sensitive_geo_masks` seed와 `view_privacy_guard_alerts_24h` 경보 임계치 조정이 추가로 필요.
