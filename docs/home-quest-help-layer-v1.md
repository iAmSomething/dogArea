# Home Quest Help Layer v1

## 목적
- 홈 미션 영역을 처음 보는 사용자가 5초 안에 `무엇 / 왜 / 어떻게 / 완료 후 변화`를 이해하게 한다.
- 산책 기반 자동 기록과 실내 보조 미션의 자가 기록 차이를 명확히 분리한다.
- 장문 고정보다 `1회성 compact coach + 재진입 가능한 상세 sheet` 구조로 설명 밀도를 제어한다.

## 진입 구조
- 첫 진입 UX: 홈 미션 섹션 상단에 1회성 compact coach card 노출
- 재진입 UX: 섹션 헤더 우측 `미션이 뭔가요?` 버튼으로 상세 sheet 재오픈
- 상세 surface: `HomeMissionGuideSheetView`

## 노출 정책
- 최초 자동 노출 소비 키: `home.mission.guide.initial.presented.v1`
- 최초 coach는 `IndoorMissionBoard.shouldDisplayCard == true`일 때만 노출
- 최초 coach는 노출 시점에 소비 처리한다.
- UI 테스트 강제 옵션
  - `-UITest.HomeMissionGuideCoachVisible`
  - `-UITest.HomeMissionGuidePresented`

## 정보 구조
1. `무엇을 하는 카드인가요?`
2. `왜 오늘 열렸나요?`
3. `어떻게 완료하나요?`
4. `완료되면 뭐가 달라지나요?`
5. 비교 카드
   - `산책 기반 자동 기록`
   - `실내 보조 미션`
6. 단계 카드
   - 이유 확인
   - 실제 행동만 +1 기록
   - 기준 충족 후 완료 확정

## 카피 원칙
- 금지: `fallback`, `replacement count`, `lifecycle`, `finalize`, `claim state`
- 권장: `오늘 날씨 때문에 실내 미션이 열렸어요`, `실제로 한 행동만 기록하세요`, `기준을 채운 뒤 완료를 눌러야 보상이 확정돼요`
- 산책은 항상 `기본 루프`, 홈 미션은 항상 `보조 흐름`으로 표현한다.

## 접근성
- coach card 버튼 최소 높이 `44pt`
- Dynamic Type 대응을 위해 `appScaledFont` 사용
- VoiceOver 탐색을 위해 surface별 식별자 고정
  - `home.quest.help.coach`
  - `home.quest.help.open`
  - `home.quest.help.sheet`
  - `home.quest.help.axis.what`
  - `home.quest.help.axis.why`
  - `home.quest.help.axis.how`
  - `home.quest.help.axis.outcome`
  - `home.quest.help.compare.auto`
  - `home.quest.help.compare.manual`

## 자동 회귀
- UI: `FeatureRegressionUITests/testFeatureRegression_HomeMissionHelpLayerExplainsWhatWhyHowAndOutcome`
- 정적: `swift scripts/home_mission_help_layer_unit_check.swift`
- 매트릭스: `FR-HOME-QUEST-002`
