# UserdefaultSetting 책임 분리 설계 v1

## 목표
- `UserdefaultSetting`의 과도한 책임을 4개 저장소로 분리해 변경 파급을 줄인다.
- 기존 호출부 호환성을 유지하면서 점진적으로 인터페이스 기반 호출로 전환한다.

## 분리 대상
1. `ProfileStore`
- 사용자 프로필/반려견 배열 저장/조회
- `UserInfo` normalize 및 선택 반려견 유효성 보정

2. `PetSelectionStore`
- 선택 반려견 id 저장/조회
- 선택 이벤트(점수/최근선택/히스토리) 및 추천 계산
- 선택 변경 Notification 송신

3. `WalkSessionMetadataStore`
- 세션 종료 메타데이터 저장/조회
- 산책 시작 카운트다운/포인트 기록 모드 설정 저장

4. `ProfileSyncOutboxStore`
- 프로필 동기화 outbox enqueue/flush/retry
- transport/coordinator 분리

## 전환 원칙
- `UserdefaultSetting`은 파사드로 축소하고, 공개 API는 우선 유지한다.
- 신규 로직은 각 Store 프로토콜 경유로 호출한다.
- 기존 스크립트 검증과 릴리즈 체크는 깨지지 않도록 유지한다.

## 검증
- 저장소 분리 여부: 파일/타입 분리 확인
- 회귀 방지: 기존 `ios_pr_check.sh` + 신규 분리 전용 유닛 체크
