# Walk Detail Back Affordance v1

## 문제
- `WalkListDetailView`가 `.navigationBarBackButtonHidden()`을 사용해 상단 기본 back affordance를 숨기고 있었다.
- 사용자는 하단 `확인` 버튼으로만 빠져나갈 수 있어 iOS 기본 탐색 규칙과 어긋났다.

## 결정
- 산책 상세는 `NavigationStack` destination 구조를 유지한다.
- 상단 dismiss는 커스텀 버튼이 아니라 기본 navigation back button을 복구한다.
- 하단 `확인` 버튼은 보조 dismiss CTA로만 유지한다.

## 구현 원칙
- `WalkListDetailView`는 `.navigationTitle("산책 기록")`와 `.navigationBarTitleDisplayMode(.inline)`를 사용한다.
- `.navigationBarBackButtonHidden()`은 사용하지 않는다.
- 커스텀 leading toolbar button을 넣지 않아 swipe back 동작을 해치지 않는다.
- 공유/저장/확인 CTA 위계는 기존 구조를 유지한다.

## 회귀 기준
- 상세 preview route 진입 시 상단 back affordance가 보여야 한다.
- back affordance 탭 후 `screen.walkList.content`가 다시 보여야 한다.
- 하단 `확인` 버튼은 여전히 존재하되 유일한 탈출 경로가 아니어야 한다.
