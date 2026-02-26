# UserInfo Enhancement v1

## 대상 이슈
- #16 UserInfomation고도화에 대한 고민

## 목적
- 사용자/반려견 정보의 기본 프로필 모델을 확장해 향후 추천/통계 품질을 높인다.

## 추가 필드
- 사용자
  - `profileMessage` (선택)
- 반려견
  - `breed` (선택)
  - `ageYears` (선택, 0~30)
  - `gender` (`unknown|male|female`)

## 적용 범위
- 회원가입 플로우 입력
  - `ProfileSettingsView`: 프로필 메시지
  - `PetProfileSettingView`: 품종/나이/성별
- 저장 모델
  - `UserdefaultSetting.save/getValue`
  - `UserInfo`, `PetInfo`
- 표시 화면
  - `NotificationCenterView`

## 비범위
- Supabase 원격 스키마 반영/마이그레이션
- 기존 사용자 대량 백필

## QA 체크
- [ ] 신규 가입에서 메시지/품종/나이/성별 입력 후 앱 재실행해도 값 유지
- [ ] 미입력 상태에서도 가입 가능(선택 필드)
- [ ] 사용자 정보 화면에 메시지/반려견 상세 정보가 정상 표시
