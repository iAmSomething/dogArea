# Rival Privacy Hard Guard v1

## 1. 목적
라이벌/근처 익명 노출 경로에서 재식별 위험을 줄이기 위해 서버 강제형 프라이버시 가드를 적용한다.

연결 이슈:
- 구현: #150
- 선행 정책: #130

## 2. 정책 요약
- 최소 표본 임계값: `k >= 20`
- 표본 미달 셀: 정확 count 비노출(`count = 0`), 상위 퍼센타일 intensity만 노출
- 반영 지연: 주간 30분, 야간 60분 (`policy_timezone` 기준)
- 민감 구역: `privacy_sensitive_geo_masks`에 매칭되는 셀 자동 마스킹
- 판정 주체: 서버(`rpc_get_nearby_hotspots`)가 최종 결정, 앱은 표현만 수행

## 3. 스키마
### 3.1 `privacy_guard_policies`
- `policy_key text pk`
- `min_sample_size int`
- `percentile_fallback double precision`
- `daytime_delay_minutes int`
- `nighttime_delay_minutes int`
- `active_window_minutes int`
- `night_start_hour int`, `night_end_hour int`
- `policy_timezone text`
- `sensitive_mask_enabled boolean`
- `updated_at timestamptz`

### 3.2 `privacy_sensitive_geo_masks`
- 민감 구역 경계 박스 기반 마스킹 룰 테이블
- `min_lat/max_lat/min_lng/max_lng` 범위 매칭

### 3.3 `privacy_guard_audit_logs`
- 요청 단위 프라이버시 점검 로그/경보
- `suppressed_hotspots`, `masked_hotspots`, `k_anon_hotspots`
- `alert_level(info|warn|critical)`

## 4. RPC 계약
`rpc_get_nearby_hotspots(center_lat, center_lng, radius_km, now_ts)`

반환 컬럼:
- 기본: `geohash7`, `count`, `intensity`, `center_lat`, `center_lng`
- 확장: `sample_count`, `privacy_mode`, `suppression_reason`, `delay_minutes`, `required_min_sample`

## 5. 운영 가이드
- 경보 모니터링 뷰: `view_privacy_guard_alerts_24h`
- 초기 운영은 기본 정책(`nearby_hotspot`) 1개로 시작
- 민감 구역은 운영자가 `privacy_sensitive_geo_masks`에 추가/비활성화

## 6. 검증 포인트
- 표본 경계값(19/20)에서 노출 모드 전환 정확성
- 야간 시간대(22~06) 지연 60분 적용
- 민감 구역 셀 미노출 확인
- `privacy_guard_audit_logs` 경보 적재 확인
