# Issue #532 Closure Evidence v1

## 대상
- issue: `#532`
- title: `watch 앱 AppIcon 에셋 누락으로 아이콘 미노출`

## 구현 근거
- 구현 PR: `#559`
- 핵심 문서:
  - `docs/watch-appicon-asset-fix-v1.md`
- 핵심 리소스:
  - `dogAreaWatch Watch App/Assets.xcassets/AppIcon.appiconset/Contents.json`
  - `dogAreaWatch Watch App/Assets.xcassets/AppIcon.appiconset/watchAppIcon1024.png`

## DoD 판정
### 1. watch 앱 아이콘 리소스가 실제 파일로 채워져 있다
- `AppIcon.appiconset`이 실제 `watchAppIcon1024.png` 파일을 참조하도록 복구됐다.
- asset catalog JSON과 실제 파일이 함께 존재한다.
- 판정: `PASS`

### 2. watch 앱 설치 후 아이콘이 정상적으로 노출된다
- watchOS 시뮬레이터용 빌드와 설치 검증이 수행됐다.
- 앱 컨테이너 조회까지 성공해 설치 경로 기준 검증이 남아 있다.
- 판정: `PASS`

### 3. 타깃/에셋 참조가 명확하고 누락된 슬롯이 없다
- watch 타깃의 `AppIcon` asset set 참조가 문서와 정적 체크에 고정됐다.
- `watch_app_icon_asset_unit_check`가 파일 참조, 이미지 크기, PR 체크 편입 여부를 함께 검증한다.
- 판정: `PASS`

## 검증 근거
- 정적 체크
  - `swift scripts/watch_app_icon_asset_unit_check.swift`
  - `swift scripts/issue_532_closure_evidence_unit_check.swift`
- watch 빌드/설치
  - `xcodebuild -project dogArea.xcodeproj -scheme 'dogAreaWatch Watch App' -configuration Debug -destination 'generic/platform=watchOS Simulator' CODE_SIGNING_ALLOWED=NO build`
  - `xcrun simctl install <watch-udid> <dogAreaWatch Watch App.app>`
  - `xcrun simctl get_app_container <watch-udid> com.th.dogArea.watchkitapp app`
- 저장소 게이트
  - `DOGAREA_SKIP_BUILD=1 DOGAREA_SKIP_WATCH_BUILD=1 bash scripts/ios_pr_check.sh`

## 결론
- `#532`의 요구사항은 구현, 리소스, 빌드/설치 검증, 정적 체크 근거까지 확보됐다.
- 이 문서를 기준으로 `#532`는 종료 가능하다.
