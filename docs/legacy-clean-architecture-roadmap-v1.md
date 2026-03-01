# DogArea 레거시 클린 아키텍처 리팩토링 로드맵 v1

## 목적
- 프레젠테이션(View/ViewModel)에서 인프라(Firebase/Supabase/Storage/Auth) 직접 의존 제거
- `Repository + Service Adapter + UseCase` 경계 명확화
- 기능 유지 상태에서 점진 전환

## 현재 레거시 핫스팟
1. View/ViewModel의 Firebase 직접 import
2. `UserdefaultSetting.shared` 직접 결합 과다
3. 대형 ViewModel(`MapViewModel`, `HomeViewModel`)의 책임 과다
4. NotificationCenter/UserDefaults 키 접근이 분산

## 단계 전략
1. `Boundary 고정`
- View/ViewModel은 protocol만 의존
- Firebase/Supabase는 `Source/Infrastructure/*` 어댑터로 고정

2. `State/Preference 분리`
- `UserdefaultSetting` 직접 접근을 `PreferenceStore` 프로토콜로 감싸기
- key-string 직접 접근 금지

3. `UseCase 분리`
- 대형 ViewModel의 핵심 흐름 분리
  - WalkSessionOrchestrator
  - HeatmapUseCase
  - NearbyPresenceUseCase
  - SeasonQuestUseCase

4. `이벤트 버스 정리`
- NotificationCenter 이벤트 이름을 enum/typed payload로 표준화
- 화면별 observer 수명 관리 통일

5. `회귀 검증 강화`
- 계층 경계 정적 체크 스크립트
- 유스케이스 단위 테스트 추가

## 이번 사이클 수행 결과 (완료)
- `SignInView`의 FirebaseAuth 직접 의존 제거
- `SigningViewModel`의 FirebaseStorage 직접 의존 제거
- `SettingViewModel`의 FirebaseStorage 직접 의존 제거 및 미사용 업로드 코드 삭제
- 인프라 어댑터 추가
  - `FirebaseAppleCredentialAuthService`
  - `FirebaseProfileImageRepository`
- 경계 회귀 체크 추가
  - `scripts/presentation_firebase_boundary_unit_check.swift`

## 다음 사이클 우선순위
1. `MapViewModel` UserDefaults/NotificationCenter 접근을 `MapPreferenceStore`로 추출
2. `HomeViewModel`의 시즌/날씨 정책 로직을 `SeasonPolicyUseCase`로 분리
3. `UserdefaultSetting`를 Store 단위 파일로 분할(`ProfileStore`, `SeasonStore`, `WalkPreferenceStore`)
