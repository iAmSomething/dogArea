# Cycle 164 - Map 설정 시트 스크롤/가독성 개선 (2026-03-01)

## 1) 이슈 확인
- 신규 이슈 발급: [#194](https://github.com/iAmSomething/dogArea/issues/194)
- 이슈명: `[Bug][Map] 지도 설정 시트 스크롤 불가/내용 잘림`
- 증상: 지도 탭 설정 시트에서 항목/목록이 길어질 때 스크롤 불가 또는 잘림.

## 2) 개발 시작
### 변경 파일
- `dogArea/Views/MapView/MapSubViews/MapSettingView.swift`
- `dogArea/Views/MapView/MapView.swift`

### 핵심 변경
1. `MapSettingView` 레이아웃 재구성
- 기존 `VStack + List` 혼합 구조를 제거하고 단일 `ScrollView` 구조로 전환.
- 상단 헤더(제목 + 닫기 버튼) 분리.
- 토글 항목을 `LazyVGrid(adaptive)` 칩 레이아웃으로 정리.
- 자동 종료 정책/히트맵 범례/산책 목록을 카드 섹션으로 분리.

2. 시트 높이 정책 개선
- `MapView`에서 설정 시트 detent를 `oneThird` 고정에서 `[.medium, .large]`로 변경.
- drag indicator 노출로 사용자가 확장 가능하게 개선.

## 3) 개발 완료
- 작은 화면(iPhone mini/SE 계열 포함)에서 설정 항목 전체 접근 가능하도록 구조 개선.
- 산책 목록 길이가 증가해도 시트 내부 스크롤로 접근 가능.

## 4) 유닛 테스트 시작
- 실행: `DOGAREA_SKIP_BUILD=1 ./scripts/ios_pr_check.sh`

## 5) 유닛 테스트 완료
- 결과: PASS
- 주요 검증 항목 포함:
  - map motion pack unit checks
  - area reference DB UI transition unit checks
  - map/home viewmodel boundary unit checks
  - project stability unit checks

## 6) 결과 문서화
- 본 문서로 회귀 리포트/변경 내역 문서화 완료.

## 7) PR / 머지
- 현재 워킹트리에 동시 진행 중인 대규모 리디자인 변경이 함께 존재하여,
  해당 묶음 정리 후 `map-setting-scroll-fix` 성격으로 분리 PR 생성 권장.
- 제안 PR 제목: `fix(map): make map setting sheet scrollable with medium/large detents`
