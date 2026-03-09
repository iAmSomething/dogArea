# Map Start Meaning Card Compact v1

## 목표
- 지도 시작 전 설명이 지도 본면을 과하게 가리지 않게 만든다.
- 산책의 의미 설명은 유지하되, `시작` CTA와 한 덱 안에서 읽히게 만든다.
- 자세한 설명은 별도 guide sheet로 보내고, 시작 전 기본 화면은 compact하게 유지한다.

## 제품 결정
- 상단의 독립 대형 설명 카드는 제거한다.
- 시작 전 설명은 하단 시작 덱의 우측 compact helper 카드 하나만 유지한다.
- helper 카드는 아래 3가지만 담는다.
  - 한 줄 제목
  - 두세 줄 요약
  - `설명 보기` CTA
- 자세한 단계 설명은 기존 `map.walk.guide.sheet`가 담당한다.

## 접근성
- compact helper 카드 자체 식별자는 `map.walk.startMeaning.card`
- 상세 설명 재진입 CTA 식별자는 `map.walk.guide.reopen`
- `설명 보기` CTA는 최소 터치 높이 `44pt`

## 회귀 포인트
- 지도 시작 전 상태에서 `start` CTA와 `map.walk.startMeaning.card`가 같은 시작 덱 안에 노출되는가
- 상단 독립 설명 카드가 다시 생기지 않는가
- `설명 보기`로 기존 guide sheet에 재진입할 수 있는가
