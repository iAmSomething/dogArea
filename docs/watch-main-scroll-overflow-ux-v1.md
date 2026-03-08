# Watch 메인 화면 overflow scroll UX v1

## 목표

- watch 메인 화면에서 정보 카드가 길어져도 모든 텍스트와 CTA에 접근 가능해야 한다.
- 핵심 CTA인 `산책 시작`, `영역 표시하기`, `산책 종료`는 작은 화면에서도 항상 접근 가능해야 한다.
- 터치 스크롤과 Digital Crown 스크롤이 모두 가능한 구조를 유지한다.

## 결정

1. 메인 화면을 `정보 스크롤 영역`과 `하단 CTA 도크`로 분리한다.
2. 상태/배너/반려견 문맥/큐 상태는 `ScrollView` 안에서 세로로 스크롤한다.
3. 핵심 액션 버튼은 `safeAreaInset(edge: .bottom)` 기반 도크에 배치해 화면 높이와 무관하게 접근 가능하게 한다.
4. CTA 버튼은 `minHeight 52pt` 이상을 유지하고, 제목/설명은 multiline 허용으로 Dynamic Type 증가에 대응한다.
5. 큐 상태 카드의 chip/action row는 `ViewThatFits`로 horizontal 우선, 실패 시 vertical fallback 한다.

## 우선순위

- 상단: 현재 산책 상태와 요약 메트릭
- 중단: 피드백 배너, 반려견 문맥, 큐/동기화 상태
- 하단 고정: 핵심 CTA

## 비범위

- WatchConnectivity contract 변경
- watch 정보 구조 전체 재설계
- 상태 문구 삭제로 overflow를 감추는 방식

## 검증

- watch 빌드 성공
- `ios_pr_check` 통과
- 정적 체크에서 `ScrollView + safeAreaInset + action dock + multiline/minHeight`를 보장
