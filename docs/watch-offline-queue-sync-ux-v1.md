#522 Watch 오프라인 큐 상태 확인 · 수동 재동기화 UX v1

## 목표

watch 사용자가 오프라인 큐를 "보이지 않는 내부 처리"가 아니라 이해 가능한 제품 기능으로 인식하게 만든다.

이번 단계는 다음만 확장한다.

- 큐 상태 카드 + 상세 시트
- 마지막 큐 적재 시각 / 마지막 ACK 결과 노출
- 오래 쌓인 큐 경고
- 수동 `다시 동기화` 액션의 제품 기준

금지 범위는 유지한다.

- 큐 프로토콜 재작성 금지
- 서버 action 계약 변경 금지

## 상태 모델

watch는 `WatchOfflineQueueStatusState`를 통해 다음을 하나의 snapshot으로 만든다.

- `pendingCount`
- `queuedActionTitles`
- `lastQueuedAt`
- `oldestQueuedAt`
- `lastAckStatus`
- `lastAckActionId`
- `lastAckAt`
- `isReachable`

`lastAck*`는 queue 상태와 분리해 UserDefaults에 영속화한다. 앱을 다시 열어도 마지막 ACK 결과를 그대로 볼 수 있어야 하기 때문이다.

## 메인 화면 카드

메인 watch 화면에는 `WatchOfflineQueueStatusCardView`를 둔다.

카드는 최소한 아래를 바로 보여준다.

- `큐 n건`
- `ACK <상태>`
- 요약 설명
- 오래 쌓인 queue warning
- `큐 상태 보기`
- `다시 동기화`

## 상세 시트

상세 시트는 다음 정보를 노출한다.

- 대기 건수
- 마지막 큐 적재 시각
- 가장 오래된 요청 시각
- 마지막 ACK 결과
- 마지막 ACK 시각
- 마지막 ACK action id
- 큐에 쌓인 action 종류 목록
- 중복 전송 안내
- 다음 행동 안내

## 수동 다시 동기화 결정

결정: `다시 동기화`는 필요하다. 다만 **reachable일 때만 실제 액션**으로 동작한다.

이유:

- 사용자는 "이미 연결은 돌아왔는데 왜 queue가 그대로인가"를 직접 해소할 경로가 필요하다.
- 반대로 오프라인일 때 `syncState`를 큐에 계속 적재하는 것은 제품 가치보다 노이즈가 크다.
- `syncState`는 상태 확인 액션이지, 오프라인에서도 반드시 보장해야 하는 write 액션이 아니다.

따라서 정책은 아래와 같다.

- `reachable == true`
  - pending queue flush
  - `syncState` 즉시 전송
  - processing banner 노출
- `reachable == false`
  - 새 `syncState`를 queue에 추가하지 않음
  - "자동 재전송을 기다린다"는 warning만 노출

## 중복 전송 안내 카피

사용자 혼란을 줄이기 위해 상세 시트에 아래 의미를 고정한다.

> 같은 `action_id`는 한 번만 반영돼요.  
> 중복 전송처럼 보여도 실제 적용은 한 번만 처리됩니다.

## 오래 쌓인 queue 경고

- 기준: `oldestQueuedAt`이 현재 시각 기준 `90초` 이상 경과
- reachable이면:
  - "지금 다시 동기화해서 상태를 재확인" 안내
- unreachable이면:
  - "iPhone 연결 후 다시 동기화" 안내

## 기존 watch 문맥 UX와의 관계

- `반려견 다시 확인`도 내부적으로 `syncState`를 사용하지만, 오프라인에서는 새 queue 적재를 만들지 않는다.
- write 성격 액션(`startWalk`, `addPoint`, `endWalk`)만 오프라인 queue 대상이다.

## 검증 기준

- watch 메인 화면에서 queue card가 보인다.
- 상세 시트에서 필수 3종 정보가 보인다.
  - 대기 건수
  - 마지막 큐 적재 시각
  - 마지막 ACK 결과
- 오프라인에서 `다시 동기화`를 눌러도 `syncState`가 queue에 쌓이지 않는다.
- 오래 쌓인 queue의 다음 행동이 명시적으로 보인다.
