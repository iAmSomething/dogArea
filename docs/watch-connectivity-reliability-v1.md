# Watch Connectivity Reliability v1

## 1. 목적
watchOS 액션 전달에서 중복 적용과 유실을 줄이기 위한 신뢰성 규약을 고정한다.

연결 이슈:
- 구현: #43

## 2. 액션 계약
iPhone <- Watch payload:

```json
{
  "action": "startWalk | addPoint | endWalk",
  "action_id": "uuid",
  "sent_at": 1770000000.0
}
```

필드 규칙:
- `action`: watch 사용자 의도
- `action_id`: 멱등키(중복 제거 기준)
- `sent_at`: watch 발생 시각(epoch seconds)

## 3. 수신 측(iPhone) 처리
- `action_id`를 최근 N개(기본 500) 캐시
- 이미 처리된 `action_id`는 무시
- 액션 적용:
  - `startWalk`: 산책이 꺼져 있으면 시작
  - `addPoint`: 산책 중일 때만 포인트 추가
  - `endWalk`: 산책 중일 때만 종료

## 4. 송신 측(Watch) 처리
- 즉시 전송 경로:
  - `session.isReachable == true`이면 `sendMessage` 시도
- 비연결/실패 경로:
  - 로컬 큐(UserDefaults)에 저장
  - 세션 활성화 후 `transferUserInfo`로 재전송
- 큐는 전송 등록 후 비움(전송 보장은 `transferUserInfo`가 담당)

## 5. 컨텍스트 동기화
iPhone -> Watch application context:

```json
{
  "isWalking": true,
  "time": 123.0,
  "area": 45.6,
  "last_sync_at": 1770000000.0
}
```

목적:
- Watch UI 상태 표시(연동 상태/시간/면적)
- 로컬 액션 시점 판단 보조

## 6. 검증 시나리오
- [ ] 동일 `action_id`를 2회 보내도 1회만 적용
- [ ] watch 오프라인에서 액션 누적 후 연결 복구 시 반영
- [ ] 산책 중이 아닐 때 `addPoint`가 무시됨
- [ ] `startWalk -> addPoint -> endWalk` 순서가 iPhone에 반영
