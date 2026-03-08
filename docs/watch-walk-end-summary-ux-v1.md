# Watch Walk End Summary UX v1

Issue: #523

## 목적
watch에서도 산책 종료 의사결정을 iPhone과 같은 의미로 정리하고, 종료 직후 최소 요약을 손목에서 바로 확인할 수 있게 한다.

## 결정
- watch 종료 플로우는 `저장하고 종료 / 계속 걷기 / 기록 폐기` 3액션을 제공한다.
- `계속 걷기`는 로컬 상태만 유지하고 서버/앱 상태를 변경하지 않는다.
- `저장하고 종료`는 기존 iPhone `endWalk` 저장 정책을 그대로 사용한다.
- `기록 폐기`는 기존 iPhone `discardCurrentWalk` 의미를 그대로 사용한다.
- watch는 저장 정책이나 점수 정책을 새로 정의하지 않는다.

## 종료 시트 정보 밀도
watch 종료 sheet에서는 아래 4개만 보여준다.
- 시간
- 넓이
- 포인트 수
- 반려견 이름

제외 항목:
- 퀘스트 상세 변화
- 영역 비교군 상세 변화
- 랭크/보상 상세

이 정보는 손목 위 정보 밀도를 넘기므로 iPhone 후속 확인으로 넘긴다.

## 종료 직후 요약
종료/폐기 반영이 완료되면 watch는 완료 요약 sheet를 자동으로 한 번 표시한다.

표시 항목:
- 결과 타이틀
  - `저장하고 종료했어요`
  - `기록을 폐기했어요`
- 시간
- 넓이
- 포인트 수
- 반려견 이름
- 후속 안내 한 줄

## 정합성 원칙
- iPhone과 의미가 다른 종료 결과를 만들지 않는다.
- watch는 `endWalk` / `discardWalk` action만 보낸다.
- 실제 저장/폐기 판단은 iPhone `MapViewModel`이 수행한다.
- watch summary는 iPhone이 action 직전 스냅샷한 payload를 application context로 다시 내려준 결과만 사용한다.

## 오프라인 fallback
- 오프라인일 때 `저장하고 종료` 또는 `기록 폐기`를 누르면 요청은 queue에 저장한다.
- 이 시점에는 최종 요약을 먼저 보여주지 않는다.
- 연결 복구 후 iPhone이 action을 반영하고 `watch_completion_summary`를 내려주면 그때 완료 요약을 보여준다.
- 사용자는 queue status card에서 `다시 동기화`를 눌러 reachability가 돌아온 뒤 수동 재전송을 유도할 수 있다.

## 구현 메모
- watch main button은 즉시 종료하지 않고 종료 decision sheet를 연다.
- iPhone application context 필드:
  - `point_count`
  - `watch_completion_summary`
- `watch_completion_summary` payload 필드:
  - `action_id`
  - `result`
  - `title`
  - `detail`
  - `pet_name`
  - `elapsed_time`
  - `area`
  - `point_count`
  - `generated_at`
  - `follow_up_note`

## 검증 포인트
- watch 종료 버튼 탭 시 3액션 sheet가 열린다.
- `계속 걷기`는 산책 상태를 유지한다.
- `저장하고 종료`는 iPhone 기존 저장 의미와 동일하다.
- `기록 폐기`는 iPhone 기존 폐기 의미와 동일하다.
- 오프라인에서는 종료 요청이 queue로 들어가고 요약은 반영 후 표시된다.
- 완료 요약은 같은 `action_id`로 한 번만 자동 표시된다.
