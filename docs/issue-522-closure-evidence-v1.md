# Issue #522 Closure Evidence v1

## 대상
- issue: `#522`
- title: `오프라인 큐 상태 확인·수동 재동기화 UX 추가`

## 구현 근거
- 구현 PR: `#550`
- 핵심 문서:
  - `docs/watch-offline-queue-sync-ux-v1.md`
- 핵심 구현 파일:
  - `dogAreaWatch Watch App/ContentsViewModel.swift`
  - `dogAreaWatch Watch App/WatchOfflineQueueStatusState.swift`
  - `dogAreaWatch Watch App/WatchOfflineQueueStatusCardView.swift`
  - `dogAreaWatch Watch App/WatchOfflineQueueStatusSheetView.swift`
  - `dogAreaWatch Watch App/ContentView.swift`

## DoD 판정
### 1. 사용자가 watch에서 큐 상태를 더 잘 이해할 수 있음
- 메인 화면에 큐 상태 카드가 추가되어 대기 건수, 마지막 적재 시각, 마지막 ACK 결과를 한눈에 볼 수 있게 됐다.
- 상세 시트에서 같은 상태를 더 자세히 확인할 수 있게 정리됐다.
- 판정: `PASS`

### 2. 오래 쌓인 오프라인 큐의 다음 행동이 명확해짐
- 오래 쌓인 큐 상태에 대해 경고/다음 행동 문구를 보여주는 snapshot 모델과 카드 구조가 도입됐다.
- `WatchOfflineQueueStatusState`가 queue age와 recovery 문맥을 같이 해석한다.
- 판정: `PASS`

### 3. 수동 동기화 필요 여부가 제품적으로 정리됨
- `다시 동기화` 액션은 유지하되, reachable 상태에서만 실제 재동기화가 실행되도록 게이트됐다.
- 오프라인 상태에서는 새 sync action을 무의미하게 누적하지 않고 안내만 보여주는 정책이 문서화됐다.
- 판정: `PASS`

### 4. idempotency 계약을 깨지 않는 선에서 UX만 확장됨
- 서버 action contract는 변경하지 않고 watch 화면의 상태/시트/설명만 확장했다.
- 관련 remote contract 정적 체크가 계속 유지된다.
- 판정: `PASS`

## 검증 근거
- 정적 체크
  - `swift scripts/watch_offline_queue_sync_ux_unit_check.swift`
  - `swift scripts/watch_remote_contract_unit_check.swift`
  - `swift scripts/issue_522_closure_evidence_unit_check.swift`
- watch 빌드
  - `xcodebuild -project dogArea.xcodeproj -scheme 'dogAreaWatch Watch App' -configuration Debug -destination 'generic/platform=watchOS Simulator' CODE_SIGNING_ALLOWED=NO build`
- 저장소 게이트
  - `DOGAREA_SKIP_BUILD=1 DOGAREA_SKIP_WATCH_BUILD=1 bash scripts/ios_pr_check.sh`

## 결론
- `#522`의 요구사항은 구현, 문서, 정적 체크, watch 빌드 근거까지 확보됐다.
- 이 문서를 기준으로 `#522`는 종료 가능하다.
