# TabBar SF Symbol Fallback Policy v1

## 목적

커스텀 탭바에서 선택 상태 아이콘을 `"\(base).fill"` 규칙으로 자동 생성하지 않습니다.

SF Symbol은 base 이름에 대응하는 fill variant가 항상 존재하지 않기 때문입니다. `list.bullet`처럼 fill variant가 없는 심볼은 선택 상태에서 아이콘이 비거나 사라질 수 있습니다.

## 규칙

1. 각 탭은 `defaultSymbolName`과 `selectedSymbolName`을 명시합니다.
2. 선택 심볼은 런타임에서 실제 유효성을 확인합니다.
3. `selectedSymbolName`이 현재 OS에서 유효하지 않으면 `defaultSymbolName`으로 fallback합니다.
4. 선택 피드백의 기본 우선순위는 다음과 같습니다.
   - 유효한 selected symbol
   - 동일 레이아웃 frame 유지
   - 기존 색상 강조 유지

## 현재 적용

- 홈: `house` -> `house.fill`
- 산책 기록: `list.bullet` -> `list.bullet.circle.fill`
- 라이벌: `person.2` -> `person.2.fill`
- 설정: `gearshape` -> `gearshape.fill`
- 지도 중앙 버튼: 기존 별도 로직 유지

## 구현 원칙

- 새 탭을 추가할 때는 먼저 explicit selected symbol을 넣습니다.
- `".fill"` 문자열 결합은 금지합니다.
- 탭 레이아웃/크기/frame은 심볼 교체 여부와 무관하게 고정합니다.
