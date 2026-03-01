# Cycle 166 - Season Motion Pack 유지보수 마감 정리 (2026-03-01)

## 1) 대상 이슈
- #143 `[Task][UI Motion][Season] 게이지/결과/실드 모션팩 v1`

## 2) 이번 사이클 개발 범위
기능 동작은 유지하면서, 시즌 모션 경로에서 iOS 17+ 기준 deprecated 경고가 발생하던 `onChange(of:perform:)` 사용을 최신 시그니처로 전환했다.

### 변경 파일
- `dogArea/Views/HomeView/HomeView.swift`

### 변경 내용
- 시즌/퀘스트/상태 메시지 반응 경로의 `.onChange(of:) { value in ... }`를
  `.onChange(of:) { _, value in ... }`로 통일.
- 포함 구간:
  - aggregation/indoor/weather 상태 토스트 정리
  - quest motion/quest completion
  - season progress/shield/motion event/result/reset token
  - 저전력 모드 반응
  - mission progress 애니메이션 반응

## 3) 검증
1. 빌드
- `xcodebuild -quiet ... build` 실행
- `HomeView.swift`의 `onChange` deprecation 경고 미재발 확인
- 컴파일 에러 없음

2. 문서/유닛 체크
- `DOGAREA_SKIP_BUILD=1 ./scripts/ios_pr_check.sh` 통과

## 4) 결론
- 시즌 모션팩(v1) 기능 항목은 기존 구현으로 충족되어 있고,
- 이번 사이클로 최신 SwiftUI 이벤트 시그니처 정리까지 완료해 유지보수 리스크를 낮췄다.
