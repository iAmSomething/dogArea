# Nearby Anonymous Hotspot v1

## 1. 목적
근처 사용자 기능을 개인정보 노출 없이 익명 밀집도(핫스팟)로 표시한다.

연결 이슈:
- 구현: #45

## 2. 프라이버시 규칙
- 기본값: `location_sharing_enabled = false`
- 명시적 동의 사용자만 presence 송신
- 지도에는 닉네임/개별 좌표를 노출하지 않고 geohash7 집계 강도만 노출

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
- TTL: `last_seen_at >= now() - interval '10 minutes'`
- 조회 단위: geohash7
- 반환: `geohash7`, `count`, `intensity`, `center_lat`, `center_lng`
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
- [ ] TTL 10분 지난 presence 집계 제외
- [ ] 지도 갱신 주기 10초 이내 반영
