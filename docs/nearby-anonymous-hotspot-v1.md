# Nearby Anonymous Hotspot v1

## 1. 목적
근처 사용자 기능을 개인정보 노출 없이 익명 밀집도(핫스팟)로 표시한다.

연결 이슈:
- 구현: #45
- 프라이버시 하드 가드: #150

## 2. 프라이버시 규칙
- 기본값: `location_sharing_enabled = false`
- 명시적 동의 사용자만 presence 송신
- 지도에는 닉네임/개별 좌표를 노출하지 않고 geohash7 집계 강도만 노출
- 최소 표본(`k>=20`) 미달 셀은 정확 count를 숨기고 상위 퍼센타일 intensity만 노출
- 반영 지연: 주간 30분, 야간 60분(`Asia/Seoul`, 기본값)
- 민감 구역(`privacy_sensitive_geo_masks`)은 집계 결과에서 자동 마스킹

## 3. 데이터 계약

### 3.1 `user_visibility_settings`
- `user_id uuid pk`
- `location_sharing_enabled boolean not null default false`
- `updated_at timestamptz`

### 3.2 `nearby_presence`
- `user_id uuid pk`
- `geohash7 text not null`
- `lat_rounded double precision not null`
- `lng_rounded double precision not null`
- `last_seen_at timestamptz not null`
- `updated_at timestamptz`

## 4. 집계 계약
- 지연 윈도우: `last_seen_at ∈ [now - (delay + 10m), now - delay]`
- 조회 단위: geohash7
- 반환: `geohash7`, `count`, `intensity`, `center_lat`, `center_lng`
  - `count`: 표본 미달/민감 셀은 `0`으로 비공개 처리
  - `intensity`: 표본 미달 셀은 percentile 기반(`privacy_mode=percentile_only`)
- 반경 필터: 기본 1km

## 5. 주기
- 송신: 산책 중 + opt-in 상태에서 30초 주기 upsert
- 조회: 지도 열람 중 10초 주기 갱신

## 6. iOS 표시
- `NearbyHotspotDTO`를 `MapCircle`로 렌더링
- 강도별 색/투명도 단계화
- 개별 사용자 정보는 UI에 미표시

## 7. 검증 체크리스트
- [ ] 비동의 사용자 송신 0건
- [ ] 연결 상태에서 30초 주기 upsert 동작
- [ ] 주간 30분/야간 60분 지연 반영 후 핫스팟 노출
- [ ] 표본 미달 셀 count 비공개 + percentile 노출 동작
- [ ] 민감 구역 셀 자동 마스킹 동작
- [ ] 지도 갱신 주기 10초 이내 반영
- [ ] `privacy_guard_audit_logs`에 요청별 점검 로그/경보 적재
