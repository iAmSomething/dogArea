# Profile Caricature Flow v2

## 목적
- 캐리커처 기능을 전용 탭에서 제거하고 프로필 생성/수정 컨텍스트로 통합한다.

## IA 변경
- 하단 탭: `홈 / 산책 목록 / 지도 / 설정`
- 캐리커처 생성 진입: `설정 > 프로필 편집`

## UX 정책
1. 프로필 생성 시(회원가입) 반려견 이미지가 있으면 비동기 캐리커처 큐잉.
2. 프로필 편집에서 선택 반려견 기준으로 "캐리커처 생성/재생성" 제공.
3. 상태(`processing/ready/failed`)와 결과 메시지를 사용자에게 명시.

## 영향 파일
- `dogArea/Views/GlobalViews/BaseView/CustomTabBar.swift`
- `dogArea/Views/GlobalViews/BaseView/RootView.swift`
- `dogArea/Views/ProfileSettingView/NotificationCenterView.swift`
- `dogArea/Views/ProfileSettingView/SettingViewModel.swift`

## 수용 기준
- 앱 탭에서 이미지 전용 탭이 사라진다.
- 프로필 편집에서 캐리커처 생성이 동작하고 상태가 반영된다.
