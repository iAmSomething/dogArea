# Heatmap Timeseries v1

## 1. 목적
산책 좌표 기록을 시간 가중치 기반으로 집계해 지도에서 "최근 기록이 더 강하게 보이는" 히트맵으로 표시한다.

연결 이슈:
- 문서/구현: #42

## 2. 입력 데이터
- 소스: `walk_points`에 대응하는 좌표 시계열
- 현재 앱 구현 매핑:
  - `Polygon.locations[]`의 `Location(createdAt, coordinate)`를 walk point로 사용

## 3. 가중치 모델
- 반감기(`halfLifeDays`) = 21일
- 감쇠 상수(`lambda`) = `ln(2) / halfLifeDays`
- 점별 가중치:
  - `ageDays = max(0, (now - recordedAt) / 86400)`
  - `weight = exp(-lambda * ageDays)`

기대값:
- 0일: 1.0
- 7일: 약 0.794
- 21일: 0.5
- 60일: 약 0.138

## 4. 공간 집계
- 인덱싱: geohash precision 7
- 집계: 같은 geohash 셀에 속하는 점들의 weight 합산
- 셀 중심: geohash decode bounding box 중심 좌표 사용

## 5. 정규화/강도 단계
- 셀 점수 정규화: `normalized = cellWeight / maxWeight`
- 범위: `[0, 1]`
- 렌더 단계: 5단계 (0~4)
  - level 0: `0.0 < score <= 0.2`
  - level 1: `0.2 < score <= 0.4`
  - level 2: `0.4 < score <= 0.6`
  - level 3: `0.6 < score <= 0.8`
  - level 4: `0.8 < score <= 1.0`

## 6. 렌더링 규칙(v1)
- 위치: `MapSubView`
- 표시 조건:
  - 산책중이 아님 (`isWalking == false`)
  - "모든 폴리곤 보기" 모드 (`showOnlyOne == false`)
  - Heatmap 토글 ON (`heatmapEnabled == true`)
- 형태: `MapCircle(center, radius: 75m)` + 단계별 색상/투명도

## 7. 결정성 보장
- 집계 key를 geohash 문자열로 고정
- 출력 정렬 기준: geohash 오름차순
- 동일 입력 + 동일 now에서 결과 순서/값 동일

## 8. 검증 체크리스트
- [ ] 최근 7일 좌표가 60일 좌표보다 높은 score를 가짐
- [ ] 동일 셀 누적 집계가 정상 동작
- [ ] score가 항상 `0...1` 범위
- [ ] 동일 입력에서 결과가 deterministic
- [ ] 지도에서 5단계 강도 차이가 시각적으로 구분됨
