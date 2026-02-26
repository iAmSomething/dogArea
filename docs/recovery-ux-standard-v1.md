# Recovery UX Standard v1

## 1. 목적
권한 거부, 오프라인, 인증 만료 상태를 사용자 행동 중심으로 통합해 "읽고 이해"보다 "누르고 복구"가 가능한 흐름을 제공한다.

연결 이슈:
- 문서/구현: #70

## 2. 공통 프레젠터
- 컴포넌트: `RecoveryActionBanner`
- 표시 상태:
  - `locationPermissionDenied`
  - `networkOffline`
  - `authExpired`
- 공통 정책:
  - 원인 텍스트 + 영향 범위 + 원탭 액션 제공
  - 보조 액션은 `닫기`

## 3. 상태별 액션 정책
- 권한 거부:
  - Primary: `설정 열기`
  - Secondary: `닫기`
- 오프라인:
  - Primary: `다시 시도`
  - Secondary: `닫기`
  - 보조 문구: "오프라인 저장 후 온라인 복귀 시 자동 동기화"
- 인증 만료:
  - Primary: `다시 로그인`
  - Secondary: `닫기`
  - 로그인 완료 후 기존 화면 복귀 보장(앱 루트 시트 플로우 유지)

## 4. 적용 범위(v1)
- 지도/산책(`MapView`): 권한 + 오프라인 + 인증 만료
- 프로필 가입(`PetProfileSettingView`): 네트워크/인증 오류 복구 배너

## 5. 오프라인 배지/토스트
- 배지:
  - 조건: 동기화 대기 > 0 && 최근 에러 코드 == `offline`
  - 위치: 지도 상단 배너 영역
- 토스트:
  - 조건: 오프라인 대기 상태에서 온라인 복구 후 pending == 0
  - 메시지: "온라인 복구: 대기 중 기록 동기화를 완료했어요."

## 6. 스냅샷 테스트 기준
- Preview snapshot case 3종 유지:
  - permission denied
  - network offline
  - auth expired
- 회귀 시 확인 포인트:
  - 문구/버튼 라벨 변경 여부
  - 배너 계층/색상 대비
  - 버튼 탭 영역 크기 유지
