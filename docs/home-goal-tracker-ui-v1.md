# Home Goal Tracker UI v1

## 1. 목적
홈 영역 비교 UI를 비활성 Picker에서 카드형 목표 트래커로 전환해 모바일 가독성과 정보 전달력을 개선한다.

연결 이슈:
- 문서/구현: #67

연결 문서:
- `docs/territory-goal-view-detail-ui-v1.md` (홈 요약 카드와 상세 화면 역할 분리 스펙)

## 2. UI 정책
- 제거:
  - 홈의 비활성 `inline Picker`
- 추가:
  - 단일 목표 카드 내 3요소
    - `현재 영역`
    - `다음 목표`
    - `남은 면적`
  - 진행률 바(`ProgressView`)로 목표 대비 진행 상태 표현
  - `목표 상세 보기` CTA를 `TerritoryGoalView`로 연결
  - `TerritoryGoalView` 내부에서 `비교군 카탈로그` CTA를 통해 `AreaDetailView`로 2단계 진입

## 3. 접근성/타이포 정책
- 카드 전체 접근성 라벨 제공
- 핵심 값 텍스트는 `lineLimit`, `minimumScaleFactor`를 적용해 줄바꿈/축소 정책 명시
- Dynamic Type 큰 사이즈에서도 카드 높이 자동 확장(고정 높이 미사용)

## 4. QA 증적 정책
- iPhone SE / Pro Max 각각 홈 스크린샷 첨부
- 확인 항목:
  - 카드 내 3요소 가독성
  - CTA 터치 영역
  - 줄바꿈/겹침/잘림 없음
