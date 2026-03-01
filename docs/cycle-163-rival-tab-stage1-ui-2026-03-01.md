# Cycle 163 - Rival Tab Stage 1 UI (2026-03-01)

## 이슈
- #192 `[Task][Rival][Stage 1 UI] 라이벌 탭 5탭 스켈레톤 + 동의/핫스팟 UX`
- 상위 연계: #132

## 구현 요약
1. 5탭 IA 반영
- `홈 / 산책 목록 / 지도 / 라이벌 / 설정` 구조로 루트 탭 분기 전환.
- 기존 `설정`(NotificationCenterView)을 5번째 탭으로 이동.

2. 라이벌 탭 스켈레톤 추가
- 신규 `RivalTabView` + `RivalTabViewModel` 추가(기존 파일 내 확장).
- 상태 배지, 프라이버시 카드, 핫스팟 카드, 리더보드 스켈레톤 카드 구성.

3. 동의/권한/게스트 분기
- 회원/게스트 분기: 게스트는 회원 전환 CTA 제공.
- 위치 권한 분기: denied 상태에서 시스템 설정 이동 경로 제공.
- 동의 시트: `동의하고 시작`으로 익명 공유 ON, `공유 중지`로 OFF.

4. 핫스팟 조회/폴링
- 공유 ON + 권한 허용 상태에서 핫스팟 조회.
- 10초 간격 폴링, 수동 새로고침 CTA 제공.
- 지도 이동 CTA(`지도에서 보기`)를 통해 중앙 지도 탭으로 전환.

## 변경 파일
1. `dogArea/Views/GlobalViews/BaseView/RootView.swift`
2. `dogArea/Views/GlobalViews/BaseView/CustomTabBar.swift`
3. `dogArea/Views/ProfileSettingView/NotificationCenterView.swift`

## 테스트
1. 문서/유닛 체크
- `DOGAREA_SKIP_BUILD=1 ./scripts/ios_pr_check.sh` 통과

2. iOS 빌드
- `xcodebuild -project dogArea.xcodeproj -scheme dogArea -configuration Debug -destination "generic/platform=iOS Simulator" CODE_SIGNING_ALLOWED=NO build` 성공

## 비고
- 이번 사이클은 Stage 1 UI 범위이며, 신고/차단/리더보드 실데이터 연동은 상위 #132/#131 단계에서 이어서 구현.
