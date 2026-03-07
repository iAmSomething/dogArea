# Realtime Ops Rollout + Kill Switch v1

## 1. 목적
실시간 공유 기능 운영 시 필수 KPI, 알람, 단계 롤아웃, 긴급 차단 절차를 단일 문서로 고정한다.

연계 운영 문서:
- `docs/backend-scheduler-ops-standard-v1.md`

## 2. 핵심 KPI 정의
| KPI | 정의 | 게이트 임계값 |
| --- | --- | --- |
| `active_sessions_5m` | 최근 5분 활성 공유 세션 수 | stage별 최소치 충족 |
| `stale_ratio_5m` | stale 상태 세션 비율 | `< 0.12` |
| `p95_latency_ms` | presence 업링크 p95 지연 | `< 350` |
| `error_rate_5m` | 최근 5분 오류율 | `< 0.01` |
| `battery_impact_percent_per_hour` | 실시간 공유 ON 기기 배터리 소모율 추정 | `< 2.5` |

### 2.1 stage별 active sessions 최소치
- `internal`: `>= 20`
- `10%`: `>= 80`
- `50%`: `>= 200`
- `100%`: `>= 400`

## 3. Alert 임계값 및 온콜 런북
### 3.1 P1 Alert
- `stale_ratio_5m >= 0.12`
- `p95_latency_ms >= 350`
- `error_rate_5m >= 0.01`
- `battery_impact_percent_per_hour >= 2.5`

### 3.2 온콜 런북 (5분 내 안정화 목표)
1. `feature_flags.rollout_percent`를 직전 단계로 즉시 롤백한다.
2. 서버 kill switch(`NEARBY_PRESENCE_ENABLED=false`)를 적용한다.
3. 클라이언트 kill switch(`ff_nearby_hotspot_v1=false`)를 강제 비활성화한다.
4. 장애 시각/영향 범위/추정 원인을 incidents 채널에 기록한다.
5. 30분 내 임시 회복 여부를 재확인하고, 불가 시 `NO-GO`로 고정한다.

## 4. 단계 롤아웃 절차
1. `internal` -> 내부 QA + 게이트 통과
2. `10%` -> 24h 관측, KPI 임계값 유지 확인
3. `50%` -> 24h 관측, KPI 임계값 유지 확인
4. `100%` -> 24h 관측, 주간 리포트 반영

## 5. Kill Switch 검증 시나리오
### 5.1 클라이언트 kill switch
- `ff_nearby_hotspot_v1`를 `false`로 설정 후 앱 재실행
- 익명 공유 시작 CTA 비노출 또는 차단 메시지 노출 확인

### 5.2 서버 kill switch
- `NEARBY_PRESENCE_ENABLED=false` 적용
- 업링크 요청이 즉시 `disabled/not configured` 경로로 전환되는지 확인
- stale/latency/error KPI가 10분 내 안정화되는지 확인

## 6. 운영 대시보드/주간 리포트
- 운영 대시보드: `public.view_rollout_kpis_24h` + 실시간 공유 KPI 패널
- 주간 리포트 템플릿: `docs/realtime-ops-weekly-report-template-v1.md`
- 자동 게이트 스크립트: `scripts/realtime_ops_rollout_gate.swift`
- GitHub Actions 게이트: `.github/workflows/realtime-ops-gate.yml`

## 7. 배포 게이트 규칙
- 배포 전 필수:
  - `swift scripts/realtime_ops_rollout_gate.swift --input <kpi-json>`
  - `swift scripts/realtime_ops_rollout_unit_check.swift`
- 하나라도 실패하면 배포를 중단하고 `NO-GO` 판정한다.
