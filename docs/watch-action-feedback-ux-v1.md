# Watch Action Feedback UX v1

## 목표
- 이슈: `#520`
- 확장 이슈: `#697`
- 대상: `dogAreaWatch Watch App`
- 범위: `startWalk`, `addPoint`, `endWalk`

watch 액션이 `전송 중 / 큐 저장 / 전달 완료 / 반영 완료 / 중복 억제 / 실패`를 짧고 일관된 방식으로 보여줘야 한다.

## 상태 원칙

### 1. 공통 상태
- `processing`: 아이폰 reply 또는 transport 등록을 기다리는 상태
- `queued`: reachability가 없어 로컬 큐에 저장된 상태
- `acknowledged`: `watch_ack status=accepted`
- `completed`: application context에서 `last_action_id_applied` 확인
- `duplicateSuppressed`: 처리 중 또는 cooldown 안쪽 재탭
- `failed`: `ignored` 또는 transport 실패 후 재시도가 불가능한 상태

### 2. 버튼 disabled 규칙
- `processing` 중에는 동일 버튼 disabled
- `queued` 중에는 `startWalk/endWalk` disabled
- `addPoint`는 짧은 cooldown 후 다시 허용
- `endWalk`는 1차 탭에서 즉시 종료하지 않고 `confirmRequired` 상태로 전환

### 3. 산책 종료 안전 UX
- 첫 탭: `산책 종료 확인`
- 3초 안 재탭: 실제 `endWalk` 전송
- 3초 경과 시 idle 복귀

## 햅틱 규칙
- `success`: 전달 완료 / 반영 완료
- `warning`: 중복 억제 / 종료 확인 / 오프라인 큐 저장
- `failure`: 요청 실패
- `processing`: 햅틱 없음

### addPoint 전용 규칙
- 탭 직후 `입력 접수`를 알려주는 즉시 햅틱을 1회 재생한다.
- 이 즉시 햅틱은 `processing` 배너와 별개다.
- `duplicateSuppressed`는 즉시 입력 접수 햅틱과 다른 방향의 짧은 햅틱을 쓴다.
- `queued`는 오프라인 큐 저장을 구분하는 햅틱을 쓴다.
- `acknowledged`는 iPhone 전달 완료용 햅틱을 쓴다.
- `completed`는 실제 반영 완료용 햅틱을 쓴다.
- `failed`는 실패 햅틱을 쓴다.
- 연속 탭에서는 `0.35초`보다 촘촘하게 즉시 햅틱을 반복하지 않는다.

## 화면 정보량 제한
- 상단: `산책 중/대기 중`, `바로 전송 가능/오프라인 큐 모드`
- 배너: 최근 액션 피드백 1개만 노출
- 메트릭: `시간`, `넓이` 2개만 유지
- 하단 상태 줄: `큐 n건`, `ACK 상태`, `동기화 시각`

## 구현 기준
- `ContentsViewModel`이 액션 상태기계와 중복 억제를 담당
- `ContentView`는 버튼/배너/메트릭 렌더링만 담당
- 버튼은 `WatchActionButtonView`, 배너는 `WatchActionBannerView`로 분리
- WatchConnectivity 계약(`watch.remote.v1`)은 변경하지 않는다

## 검증 기준
- watch 빌드 성공
- `start/addPoint/endWalk` 각각에 대해:
  - 처리 중 상태 존재
  - 큐 저장 상태 존재
  - 중복 억제 피드백 존재
  - 종료 확인 단계 존재
  - 햅틱 분기 존재
- 특히 `addPoint`는:
  - 탭 즉시 촉각 피드백 존재
  - 큐 저장/전달 완료/반영 완료/실패가 구분됨
  - duplicate 억제와 즉시 접수 햅틱이 혼동되지 않음
