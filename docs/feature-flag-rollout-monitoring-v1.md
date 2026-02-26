# Feature Flag + Rollout Monitoring v1

## 1. 목표
- 기능별 ON/OFF 제어를 런타임에서 수행한다.
- 단계별 릴리즈(내부 -> 10% -> 50% -> 100%)를 체크리스트 기반으로 운영한다.
- 1차 KPI를 서버 지표로 수집하고, 릴리즈 단계 승급/중단 기준으로 사용한다.

## 2. 대상 플래그
- `ff_heatmap_v1`
- `ff_caricature_async_v1`
- `ff_nearby_hotspot_v1`

## 3. 런타임 제어 모델
- 앱 시작 후 원격 플래그를 조회하고 로컬 캐시에 저장한다.
- 각 플래그는 `is_enabled` + `rollout_percent(0~100)` 조합으로 최종 활성 여부를 계산한다.
- `rollout_percent`는 `app_instance_id + flag_key` 해시 버킷(0~99)에 의해 결정한다.
- 원격 조회 실패 시 마지막 캐시값을 사용한다.

## 4. 운영 체크리스트

### 4.1 사전 점검
- [ ] `feature_flags` 테이블에 3개 플래그가 존재한다.
- [ ] 기본값(`is_enabled=true`, `rollout_percent=100`)이 설정되어 있다.
- [ ] `feature-control` Edge Function 배포 완료.
- [ ] 앱에서 플래그별 ON/OFF 반영 동작 확인.

### 4.2 단계별 롤아웃
- [ ] 내부 테스트: `rollout_percent=100` (내부 사용자만)
- [ ] 10%: 크래시/핵심 KPI 이상치 없음
- [ ] 50%: p95 지연 및 실패율 기준 충족
- [ ] 100%: 24시간 이상 안정성 확인

### 4.3 롤백 기준
- [ ] 산책 저장 성공률 95% 미만
- [ ] watch action 유실률 2% 초과
- [ ] 캐리커처 성공률 90% 미만
- [ ] nearby opt-in 비율 급락(직전 대비 30% 이상 하락)

## 5. KPI 수집 이벤트
- `walk_save_success`, `walk_save_failed`
- `watch_action_received`, `watch_action_processed`, `watch_action_applied`, `watch_action_duplicate`
- `caricature_success`, `caricature_failed`
- `nearby_opt_in_enabled`, `nearby_opt_in_disabled`

## 6. KPI 집계 뷰
`view_rollout_kpis_24h`에서 최근 24시간 지표를 조회한다.

- `walk_save_success_rate`
- `watch_action_loss_rate` (`1 - applied / processed`)
- `caricature_success_rate`
- `nearby_opt_in_ratio`

## 7. 릴리즈 게이트
- 단계 승급은 `view_rollout_kpis_24h` + QA 체크리스트를 함께 통과해야 한다.
- 하나라도 실패 시 즉시 해당 플래그 `rollout_percent`를 직전 단계로 되돌린다.
