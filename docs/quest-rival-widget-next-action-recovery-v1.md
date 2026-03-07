# Quest/Rival Widget Next Action Recovery v1

## 목적

Quest/Rival 위젯이 단순 진행률/순위 표시를 넘어서, 현재 상태 기준 `다음 행동`을 명확하게 제안한다.

범위는 위젯 snapshot, widget CTA, 앱 deep link route, 홈 퀘스트 카드 진입 UX까지다.

## 범위 밖

- 퀘스트 정책 변경
- 라이벌 리더보드 정책 변경
- 보상 지급 규칙 변경

## 상태별 기준

| 상태 | 판단 기준 | primary CTA | secondary CTA | 사용자 문구 |
| --- | --- | --- | --- | --- |
| claim 가능 | `questClaimable == true` and `questInstanceId != nil` | `보상 받기` | `라이벌 보기` | `지금 보상 받을 수 있어요` |
| claim 처리 중 | `snapshot.status == claim_in_flight` | `앱에서 마무리` | `퀘스트 상세 보기` | 위젯 요청은 접수됐고 앱에서 최종 상태를 확인해야 함 |
| claim 실패 | `snapshot.status == claim_failed` | `앱에서 마무리` | `퀘스트 상세 보기` | 복구/재시도 경로를 앱에서 이어야 함 |
| claim 완료 | `snapshot.status == claim_succeeded` | `라이벌 보기` | `퀘스트 상세 보기` | 보상 반영 후 순위 흐름 확인 |
| 진행 부족 | `questClaimable == false` and `questProgressRatio < 1` | `퀘스트 상세 보기` | `라이벌 보기` | `보상까지 N 남음` |
| 상태 어긋남 | `questProgressRatio >= 1` but `questClaimable == false` | `앱에서 마무리` | `퀘스트 상세 보기` | 앱/위젯 상태가 아직 완전히 맞지 않을 수 있음 |
| empty | `snapshot.status == empty_data` | `퀘스트 상세 보기` | 없음 | 준비 중 copy |

## 앱 라우팅

새 widget action kind:

- `open_quest_detail`
- `open_quest_recovery`

둘 다 홈 탭으로 진입하지만, 홈에서는 다음을 적용한다.

1. 퀘스트 탭을 `일일`로 고정
2. 퀘스트 섹션까지 자동 스크롤
3. route kind에 맞는 배너 노출

## 복구 원칙

- 위젯에서 `claim`을 눌렀는데 `questInstanceId`를 복원하지 못하면 즉시 `claim_failed`로 저장한다.
- 이 경우 generic `라이벌 보기`로 보내지 않는다.
- 문구는 `위젯 상태가 최신이 아니에요. 앱에서 퀘스트 카드를 다시 확인해 주세요.`로 고정한다.

## 구현 원칙

- 서버 RPC는 그대로 사용한다.
- `next action` 계산은 widget presentation layer에서 수행한다.
- 홈 진입 context는 `HomeExternalRoute`로 전달한다.
- transient `claim_failed / claim_succeeded`를 앱 진입 직후 sync로 즉시 덮어쓰지 않는다.

## 검증

정적 검증:

- `scripts/quest_rival_widget_next_action_recovery_unit_check.swift`

UI 회귀:

- `FeatureRegressionUITests.testFeatureRegression_QuestWidgetRouteOpensQuestMissionBoard`
- `FeatureRegressionUITests.testFeatureRegression_QuestWidgetRecoveryRouteOpensQuestMissionBoard`

기본 PR 체크:

- `bash scripts/ios_pr_check.sh`
