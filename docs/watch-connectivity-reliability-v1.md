# Watch Connectivity Reliability v1 (Issue #25)

## 1. 목적
watchOS 원격 액션(`startWalk/addPoint/endWalk`)을 iPhone 상태머신에 멱등/복구 가능하게 반영한다.

연결 이슈:
- 구현: #25

## 2. 액션 계약 (Watch -> iPhone)
버전 고정: `watch.remote.v1`

```json
{
  "version": "watch.remote.v1",
  "type": "watch_action",
  "action": "startWalk",
  "action_id": "uuid",
  "sent_at": 1770000000.0,
  "payload": {
    "action": "startWalk",
    "action_id": "uuid",
    "sent_at": 1770000000.0
  }
}
```

규칙:
- `action_id`는 멱등키(중복 수신 제거 기준)
- `payload`가 표준 계약이며, 상위 필드는 레거시 호환용으로도 유지
- `type != watch_action` 인 메시지는 무시

## 3. ACK 계약 (iPhone -> Watch reply)

```json
{
  "version": "watch.remote.v1",
  "type": "watch_ack",
  "status": "accepted | duplicate | ignored",
  "action": "startWalk",
  "action_id": "uuid",
  "last_sync_at": 1770000001.0
}
```

## 4. iPhone 수신 처리
- 최근 `action_id` 500개 캐시 후 dedupe
- 액션 적용 기준
  - `startWalk`: 미산책 상태에서만 시작
  - `addPoint`: 산책 중 + 위치가 있을 때만 추가
  - `endWalk`: 산책 중일 때만 종료
  - `syncState`: 상태 재동기화
- 적용 결과는 `syncWatchContext(force: true)`로 즉시 피드백

## 5. 상태 컨텍스트 계약 (iPhone -> Watch)

```json
{
  "version": "watch.remote.v1",
  "type": "watch_state",
  "isWalking": true,
  "time": 123.0,
  "area": 45.6,
  "last_sync_at": 1770000002.0,
  "watch_status": "워치 동기화 12:34:56",
  "last_action_id_applied": "uuid"
}
```

## 6. 오프라인/재연결 동작
- Watch 즉시 전송: `sendMessage` + ACK 처리
- 즉시 전송 실패 시: 로컬 큐(UserDefaults)에 적재
- 재연결 시: 큐를 `transferUserInfo`로 등록하여 순차 재전송
- 큐 등록 후 로컬 큐는 비워 `중복 등록`을 방지

## 7. 검증 시나리오
- [ ] 워치에서 `startWalk -> addPoint x3 -> endWalk` 순서 반영
- [ ] 동일 `action_id` 재수신 시 duplicate ACK + 1회 적용
- [ ] 오프라인 액션 누적 후 재연결 시 큐 반영
- [ ] 컨텍스트(`time/area/last_action_id_applied`)가 Watch UI와 일치
