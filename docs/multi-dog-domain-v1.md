# Multi-Dog Domain & UX Spec v1

## 1. 목적
다견가정 지원의 도메인 규칙, UX, 데이터 경계를 확정한다.
본 문서는 구현 이슈 #26, #27의 선행 명세다.

연결 이슈:
- 문서: #39
- 구현: #26 (다견 1차), #27 (N:M 2차)

## 2. 목표 범위
- 대표 반려견 선택 규칙
- 산책 세션 1차(1마리)와 2차(N:M) 확장 경로
- 홈/통계/목록/설정 화면의 반려견 기준 분리 규칙

## 3. 용어
- Owner: 계정 사용자
- Pet: 반려견 엔티티
- Selected Pet: 현재 화면/통계의 기본 기준 반려견
- Walk Session: 산책 1회 기록

## 4. 도메인 규칙

### 4.1 반려견 상태
- 최소 1마리 이상 활성 반려견이 있어야 산책 가능
- `is_active=false` 반려견은 신규 산책 선택 목록에서 제외
- 삭제 대신 비활성화(soft delete) 우선

### 4.2 Selected Pet 규칙
1. 앱 최초 진입:
- 활성 반려견 중 첫 번째를 `selectedPetId`로 설정

2. 반려견 추가:
- 기존 선택 유지

3. 선택된 반려견 비활성화/삭제:
- 다음 우선순위 활성 반려견으로 자동 전환
- 없으면 온보딩/반려견 추가 유도 화면

4. 동기화 충돌:
- 서버값 우선, 로컬 캐시 갱신

### 4.3 산책 귀속 규칙
- 1차 릴리스(v1): 산책 1건은 1마리(`walk_sessions.pet_id`)에 귀속
- 2차 릴리스(v2): `walk_session_pets`로 N:M 연결
  - `walk_sessions.pet_id`는 대표 반려견(primary pet)로 유지

### 4.4 통계 기준
- 기본: Selected Pet 기준
- 옵션: 전체 반려견 합산(aggregate mode)
- 비교 카드/명소 달성은 선택 모드에 따라 계산 범위가 달라짐

## 5. 화면별 UX 규칙

## 5.1 홈(Home)
- 기본 탭: Selected Pet 기준 면적/시간/주간 통계
- 상단 또는 필터에서 `대표 강아지` 변경 가능
- 전체 보기 토글 제공(Selected/All)

## 5.2 지도(Map)
- 산책 시작 전 Selected Pet 확정
- 산책 진행 중 pet 변경 금지
- 종료 시 세션은 시작 시점 pet 기준으로 저장

## 5.3 목록(Walk List)
- 기본: Selected Pet 필터
- 전체 보기 선택 시 pet badge 표시

## 5.4 설정(Profile/Settings)
- 반려견 목록 관리(추가/비활성/대표 선택)
- 대표 선택 시 즉시 로컬 + 원격 동기화

## 6. 화면 상태 전이표

| 화면 | 상태 | 이벤트 | 다음 상태 | 비고 |
|---|---|---|---|---|
| 홈 | pet_selected | 대표 변경 | pet_selected(new) | 통계 재조회 |
| 홈 | pet_selected | 전체 토글 ON | all_selected | 합산 통계 |
| 지도 | idle | 산책 시작 | walking | 시작 시 pet lock |
| 지도 | walking | 영역 추가 | walking | same pet 유지 |
| 지도 | walking | 산책 종료 | completed | 해당 pet로 저장 |
| 목록 | filtered_by_pet | 전체 토글 ON | all_walks | pet badge 노출 |
| 설정 | pets_loaded | 대표 변경 | pets_loaded | selectedPetId 동기화 |
| 설정 | pets_loaded | 반려견 비활성 | pets_loaded | 대표였으면 자동 재선택 |

## 7. 데이터 모델 경계

## 7.1 앱 로컬(UserDefaults)
- `petInfo: [PetInfo]`
- `selectedPetId: UUID`
- 로컬은 UI 반응성 캐시, 정본은 서버

## 7.2 Supabase
- `pets` (owner_user_id, name, photo_url, caricature_url, is_active)
- `walk_sessions` (pet_id)
- `walk_session_pets` (v2 N:M)

## 8. 마이그레이션 가이드

## 8.1 로컬 데이터 마이그레이션
대상: 구버전 단일 반려견 사용자

절차:
1. 앱 실행 시 `petInfo` 존재 여부 확인
2. 비어있고 구버전 `petName/petProfile` 흔적이 있으면 1마리 배열로 승격
3. `selectedPetId`가 nil이면 첫 반려견 id로 채움
4. 변환 결과를 즉시 저장

검증:
- 기존 사용자도 홈/지도/목록 진입 시 crash 없음
- selectedPet가 nil인 상태가 남지 않음

## 8.2 서버 데이터 마이그레이션
1차(v1):
- `walk_sessions.pet_id` 필수 유지
- `walk_session_pets`는 비어 있어도 허용

2차(v2, N:M):
1. 기존 `walk_sessions` 행마다 `(session_id, pet_id)`를 `walk_session_pets`에 백필
2. 신규 생성부터 다중 pet insert 허용
3. 조회는 `walk_session_pets` 우선, fallback `walk_sessions.pet_id`

## 9. API/Repository 계약 영향
- `fetchWalkSessions(ownerId, petId?)`
  - `petId=nil`이면 전체 반려견
- `saveWalk(session, points)`
  - v1: 단일 pet 필수
  - v2: `saveWalk(session, points, petIds)`로 확장
- `setSelectedPet(ownerId, petId)`
  - 로컬/원격 동기화 보장

## 10. 실패/예외 규칙
- Selected Pet이 비활성화되면 자동 대체 + 안내 토스트
- 반려견이 0마리면 산책 시작 버튼 비활성 + 반려견 추가 CTA
- 서버 동기화 실패 시 로컬 반영 후 재시도 큐 적재

## 11. QA 체크리스트
1. 반려견 2마리 이상에서 대표 전환 시 홈 통계 즉시 변경
2. 산책 중 대표 변경 UI 차단 동작
3. 대표 반려견 비활성화 시 자동 재선택 동작
4. 목록 필터(Selected/All) 결과 정합성
5. 단일 반려견 구버전 사용자 데이터 승격 성공

## 12. 비범위
- 친구/공유 기반 반려견 협업 관리
- 다견 산책의 권한 분리(다중 오너)
- 반려견별 고급 목표/리포트 기능
