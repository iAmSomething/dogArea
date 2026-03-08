# Watch Sync Recovery UX v1

Issue: #524

## 목표
- watch 사용자가 "상태가 어긋난 것 같다"는 느낌을 제품 안에서 바로 이해하게 한다.
- 자동 동기화는 기본값으로 유지하고, 수동 동기화는 recovery 용도로만 보수적으로 제공한다.
- `WCSession` 계약을 바꾸지 않고도 회복 경로와 피드백을 명확하게 만든다.

## out-of-sync 징후 기준
watch는 아래 신호를 조합해 `WatchSyncRecoveryState`를 만든다.

- `iPhone 연결 끊김`
  - `isReachable == false`
- `마지막 동기화 오래됨`
  - `lastSyncAt` 기준 `60초` 이상 새 application context가 없음
- `초기 동기화 전`
  - `lastSyncAt == nil`
- `큐 장기 적재`
  - `oldestQueuedAt` 기준 `90초` 이상 대기
- `ACK 아직 없음`
  - pending queue가 남아 있는데 `lastAckAt == nil` 또는 ACK 상태가 여전히 대기

이 징후들은 카드와 상세 시트에서 공통으로 쓰는 `signals` 배열로 노출한다.

## recovery 상태 기계
수동 recovery는 아래 4단계만 가진다.

- `idle`
  - 특별한 recovery가 진행 중이 아님
- `processing`
  - 사용자가 수동 동기화를 눌렀고, 최신 ACK/application context를 기다리는 중
- `waiting`
  - 수동 동기화 이후 `8초` 안에 최신 응답이 오지 않음
  - 또는 진행 중 reachability가 끊김
- `recovered`
  - 수동 recovery 요청 시각 이후의 `lastSyncAt` 또는 `lastAckAt` 갱신을 확인함

`processing` 또는 `waiting` 이후 실제 동기화 확인이 되면 `recovered`로 전환하고, 성공 배너 노출 후 잠시 뒤 `idle`로 되돌린다.

## 수동 동기화 역할
결정: `수동 동기화`는 유지한다. 다만 **자동 동기화를 대체하지 않는 recovery action**으로 제한한다.

- 온라인(`reachable == true`)
  - pending queue flush 시도
  - `syncState` 즉시 전송
  - recovery phase를 `processing`으로 전환
- 오프라인(`reachable == false`)
  - 새 `syncState`를 queue에 쌓지 않음
  - `연결 후 다시 동기화` 안내만 보여줌

즉, write 성격 액션은 여전히 queue가 책임지고, `syncState`는 상태 확인용 recovery action으로만 남긴다.

## guard 기준
- 수동 동기화 연타 방지 cooldown: `15초`
- recovery 응답 grace window: `8초`
- cooldown 중 버튼 상태:
  - 제목: `잠시 후 다시`
  - 버튼 비활성
  - 남은 시간 문구 노출

이 guard는 "사용자에게 아무것도 못 하게 막기"보다 "불필요한 반복 확인을 줄이는 것"이 목적이다.

## 카드/시트 표면 규칙
메인 카드와 상세 시트는 아래 문맥을 공유한다.

- headline
  - `동기화 정상`
  - `상태 확인 필요`
  - `다시 확인 중`
  - `응답 대기 중`
  - `동기화 확인됨`
- signals
  - 짧은 badge/chip 형태로 노출
- CTA
  - `지금 다시 동기화`
  - `상태 다시 확인`
  - `연결 후 다시 동기화`
  - `잠시 후 다시`
  - `다시 확인 중`

상세 시트에는 아래 추가 정보가 들어간다.

- `회복 상태`
- `마지막 동기화`
- `마지막 ACK`
- `마지막 ACK 시각`
- `어긋남 징후`
- `중복 전송 안내`
- `다음 행동`

## 성공/실패/대기 피드백
- 수동 동기화 직후
  - processing banner
  - headline: `다시 확인 중`
- grace window 초과
  - warning banner
  - headline: `응답 대기 중`
- 최신 sync/ACK 확인
  - success banner
  - headline: `동기화 확인됨`

이번 단계에서는 별도 실패 terminal state를 추가하지 않는다. watch는 서버 직접 통신을 하지 않으므로, 실패보다는 `waiting`과 `unreachable` 문맥으로 보수적으로 안내한다.

## 금지 범위 확인
- `WCSession` message / application context 계약 전면 변경 없음
- 서버와의 직접 통신 추가 없음
- `syncState`를 write queue의 새로운 canonical action으로 승격하지 않음

## 검증 기준
- watch 메인 카드에서 out-of-sync 징후가 칩으로 보인다.
- 상세 시트에 `어긋남 징후`와 `회복 상태`가 노출된다.
- 수동 동기화 이후 `processing -> waiting/recovered` 전이가 가능하다.
- cooldown 동안 반복 탭이 막힌다.
- 오프라인에서는 수동 동기화가 새 queue spam을 만들지 않는다.
