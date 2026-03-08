# WalkList Detail Design Refresh v1

## 목적
- 산책 상세 화면을 `기록 회고 + 공유/저장 + 세션 메타 확인`에 맞는 정보 구조로 재정렬한다.
- 지도, 핵심 지표, 포인트 타임라인, 종료 메타, CTA를 같은 화면 안에서 자연스럽게 읽히도록 만든다.
- 기존 동작(공유, 사진 저장, dismiss, 포인트 선택, 지도 강조, 메타 노출)은 보존한다.

## 화면 구조
1. 상단 요약 카드
- 날짜/시간, 반려견 문맥, 종료 상태 배지
- 영역 넓이, 산책 시간, 포인트 수, 종료 시각을 2열 metric card로 노출
- 영역 넓이 카드는 탭으로 `㎡ / 평` 전환 유지

2. 지도 카드
- 지도는 핵심 섹션이지만 첫 화면을 독점하지 않는다.
- 현재 선택된 포인트를 한 줄 요약으로 보여주고, 포인트 칩과 연결된다는 사실을 명시한다.
- 포인트가 부족하면 placeholder copy로 자연스럽게 fallback 한다.

3. 포인트 타임라인 카드
- 포인트 역할(`영역 표시` / `이동 경로`)과 시간을 같이 보여준다.
- 긴 기록은 대표 시점만 먼저 노출하고 footnote로 압축 사실을 설명한다.
- 선택된 칩은 지도 강조와 같은 문맥으로 보이도록 active state를 유지한다.

4. 세션 메타 카드
- 반려견, 시작 시각, 종료 시각, 종료 사유, 포인트 요약을 한 카드에 정리한다.
- 종료 메타가 없을 때는 fallback row를 노출하고 레이아웃은 유지한다.

5. CTA 위계
- Primary: `공유하기`
- Secondary: `사진으로 저장하기`
- Dismiss: `확인`
- 세 버튼을 같은 색/같은 무게로 반복하지 않는다.

## 사용자 문맥 결정
- 반려견 이름은 `WalkSessionMetadata.petId -> WalkDataModel.petId -> 미지정` 순서로 해석한다.
- 공유 payload와 저장 로직은 기존 구현을 유지한다.
- 지도 캡처가 없으면 공유는 텍스트 요약만으로 fallback 한다.

## UI 테스트 기준
- `screen.walkListDetail.content`
- `walklist.detail.hero`
- `walklist.detail.map`
- `walklist.detail.timeline`
- `walklist.detail.meta`
- `walklist.detail.action.share`
- `walklist.detail.action.save`
- `walklist.detail.action.dismiss`

## 비범위
- 공유 로직 변경 금지
- 사진 저장 로직 의미 변경 금지
- 산책 데이터 모델 변경 금지
- 지도 렌더링 엔진 교체 금지
