# Cycle 134 Report — Weather Stage 2 Server Engine (2026-02-27)

## 1. 대상
- Issue: `#134 [Task][Weather][Stage 2] 목표 치환/스트릭 보호 엔진 구현`
- Branch: `codex/cycle-134-weather-engine-server`

## 2. 구현 요약
- Supabase 서버 엔진(마이그레이션) 구현
  - 위험 단계별 대체 매핑 테이블(`weather_replacement_mappings`) 추가
  - 런타임 정책 테이블(`weather_replacement_runtime_policies`) 추가
  - 치환 이력 원장(`weather_replacement_histories`) 추가
  - Shield 원장(`weather_shield_ledgers`) 추가
  - 14일 감사 뷰(`view_weather_replacement_audit_14d`) 추가
- 서버 확정 RPC 구현
  - `rpc_apply_weather_replacement`
  - 일일 최대 1회 치환 + 주간 1회 Shield 자동 적용
  - 차단 사유(`risk_clear_or_unknown`, `daily_limit_reached`) 반환
- `sync-walk` points stage 연계
  - `rpc_apply_weather_replacement` 호출
  - 응답에 `weather_replacement_summary` 추가
- 문서/운영 가이드 확장
  - 정책 명세 문서 + 스키마 문서 + 마이그레이션 검증 문서 반영

## 3. 변경 파일
- `supabase/migrations/20260228003000_weather_replacement_shield_engine.sql`
- `supabase/functions/sync-walk/index.ts`
- `docs/weather-replacement-shield-engine-v1.md`
- `docs/supabase-schema-v1.md`
- `docs/supabase-migration.md`
- `docs/cycle-134-weather-stage2-engine-report-2026-02-27.md`
- `scripts/weather_stage2_engine_unit_check.swift`
- `scripts/ios_pr_check.sh`
- `README.md`

## 4. 검증
- `swift scripts/weather_stage2_engine_unit_check.swift` -> PASS
- `DOGAREA_SKIP_BUILD=1 bash scripts/ios_pr_check.sh` -> PASS

## 5. 리스크/후속
- 현재 클라이언트가 `weather_risk_level`을 points payload에 안정적으로 포함하지 않으면 기본 `clear` 경로로 동작한다. Stage 3/후속에서 payload 전송 보강이 필요하다.
- 주차 계산은 서버 UTC 기준으로 처리되므로, 사용자 로컬 주차 기준과 차이가 있는지 운영 데이터로 점검 필요.
