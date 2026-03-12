# Map Season Tile Occupation Visualization v1

## 목표
- 지도 본면의 시즌 오버레이를 `색 원`이 아니라 `점령 상태 지도`로 읽히게 만든다.
- 사용자가 설정 시트를 열지 않아도 `점령`, `유지`, `강도`, `산책 반영 방식`을 바로 이해하게 만든다.
- 기본 top chrome은 slim top chrome으로 유지하고, 긴 설명은 별도 overview sheet로 분리한다.

## 이번 결정
- 시즌 셀은 더 이상 원형 heatmap으로 그리지 않는다.
- geohash 셀 경계를 복원해서 `격자 타일`처럼 보이는 polygon overlay로 렌더링한다.
- 시각 규칙은 다음과 같이 고정한다.
  - `굵은 실선 테두리 = 점령`
  - `점선 테두리 = 유지`
  - `채움은 보조 신호`, `stroke가 주 신호`
  - `채움이 진할수록 강도가 높은 칸`이지만 본면을 덮지 않을 정도로만 유지한다.
- 지도 상단에는 숫자 pill만 두지 않고 compact summary card를 함께 노출한다.
- 의미 설명, 강도 범례, guide CTA는 기본 chrome이 아니라 overview sheet로 분리한다.

## 본면 계약
### 1. 타일 렌더링
- 각 셀은 geohash bounds 기반 `MapPolygon`으로 그린다.
- 셀 수는 기존 heatmap cell count와 동일하게 유지한다.
- 낮은 강도 타일부터 먼저, 높은 강도 타일을 나중에 렌더링해 상위 점령 상태가 묻히지 않게 한다.
- 지도 내 레이어 우선순위는 다음 순서를 기본으로 한다.
  - 시즌 fill
  - 저장된 polygon surface
  - 시즌 stroke
  - 선택 halo
  - 현재 산책 route / marker / hotspot
- route가 보이는 상황에서는 `현재 산책 route`가 항상 시즌 stroke보다 위에서 읽혀야 한다.
- selection은 fill darkening이 아니라 `halo + stroke`로만 강조한다.

### 1-1. 모드별 우선순위
- 시즌 타일만 보이는 모드
  - 시즌 fill
  - 시즌 stroke
  - 선택 halo
  - hit target / hotspot
- 시즌 타일 + 과거 polygon 모드
  - 시즌 fill
  - 저장 polygon surface
  - 시즌 stroke
  - 선택 halo
  - polygon marker / hotspot
- 시즌 타일 + 현재 산책 route 모드
  - 시즌 fill
  - 저장 polygon surface
  - 시즌 stroke
  - 선택 halo
  - 현재 산책 route
  - current marker / hotspot

### 1-2. 채움 규칙
- 시즌 fill은 `seasonOnly / seasonWithStoredPolygonSurface / seasonWithActiveWalkRoute` 3개 시나리오별로 더 옅게 보정한다.
- active route가 같이 보일 때는 fill을 가장 약하게 내린다.
- 날씨 tint가 켜진 상태에서도 검게 눌리지 않도록 fill opacity를 추가로 보정한다.

### 2. 상태 시그널
- `점령`
  - warm tone stroke
  - 굵은 실선 테두리
- `유지`
  - cool tone stroke
  - 점선 테두리
- 색상만 바꾸는 방식으로 상태를 구분하지 않는다.
- 선택 상태는 fill을 더 진하게 덮지 않고 halo와 stroke 강조로만 표현한다.

### 3. 강도 시그널
- 4단계 스트립은 overview sheet 안에 노출한다.
- 각 단계는 `1단계 유지`, `2단계 유지`, `3단계 점령`, `4단계 점령`으로 읽히게 한다.

### 4. 산책 관계 설명
- overview sheet에 `산책 경로가 지나간 칸이 누적되며 다음 단계로 올라간다`는 문장을 고정 노출한다.
- 사용자는 지도 본면에서 `내 산책이 이 격자에 반영된다`는 인과를 바로 이해해야 한다.

## Top Chrome 계약
- idle 상태에서는 `시즌 점령 지도`, `점령 n칸`, `유지 n칸`, `최고 단계`만 노출하는 compact card를 쓴다.
- walking 상태에서는 summary card를 접고 pill만 유지한다.
- 긴 안내, 범례, guide entry, 대표 칸 fallback detail entry는 overview sheet에서 제공한다.

## 설정 시트 계약
- 설정 시트의 토글 이름은 `산책 분포`가 아니라 `시즌 점령 지도`로 노출한다.
- 설정 시트 안에도 동일한 의미 체계를 다시 보여주되, 본면의 보조 설명이어야 한다.

## 성능 결정
- 도형 수는 기존 heatmap cell 수와 동일하게 유지한다.
- `MapCircle`를 `MapPolygon`으로 대체하지만, 셀 집계/refresh gating 구조는 그대로 유지한다.
- snapshot/trigger gating 이슈들(`#503`, `#504`) 위에서만 시각화를 바꾼다.

## QA 포인트
1. 지도만 봐도 시즌 영역이 `격자 타일`로 인지된다.
2. 범례 없이도 대략 `점령`과 `유지`를 구분할 수 있다.
3. 기본 top chrome은 compact height를 유지하고 지도 본면을 과도하게 가리지 않는다.
4. overview sheet가 `강도`와 `산책 반영 방식`을 별도 표면에서 설명한다.
5. 설정 시트를 열지 않아도 시즌 레이어의 존재와 의미가 드러난다.
