# Watch AppIcon asset fix v1

## 목표
- watch 앱 타깃의 `AppIcon` 에셋에 실제 아이콘 파일을 채운다.
- `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` 참조와 실제 리소스가 일치하도록 고정한다.
- watch simulator 설치까지 확인해서 아이콘 누락 상태를 재발 방지한다.

## 이번 수정
- `dogAreaWatch Watch App/Assets.xcassets/AppIcon.appiconset/watchAppIcon1024.png` 추가
- watch `Contents.json`이 위 파일을 참조하도록 정리
- 메인 앱 아이콘 원본과 동일한 브랜드 자산을 사용해 시각 일관성 유지

## 검증 기준
1. watch `AppIcon.appiconset` 안에 실제 PNG 파일이 존재한다.
2. `Contents.json`이 해당 파일을 참조한다.
3. PNG 해상도는 `1024x1024`다.
4. watch 타깃 build 시 asset compile이 성공한다.
5. watch simulator에 앱 설치가 성공하고 bundle container를 조회할 수 있다.

## 설치 검증 커맨드
```bash
WATCH_UDID='<watch-udid>'
APP_PATH=$(find "$HOME/Library/Developer/Xcode/DerivedData" -path '*Debug-watchsimulator/dogAreaWatch Watch App.app' | head -n 1)
xcrun simctl boot "$WATCH_UDID"
xcrun simctl bootstatus "$WATCH_UDID" -b
xcrun simctl install "$WATCH_UDID" "$APP_PATH"
xcrun simctl get_app_container "$WATCH_UDID" com.th.dogArea.watchkitapp app
```

## 범위 밖
- 전체 브랜드 리뉴얼
- widget/complication 전용 아이콘 설계
- watch AppIcon 다중 variant 확장
