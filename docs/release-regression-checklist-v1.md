# Release Regression Checklist v1

## 1. 목적
고도화 이후 핵심 경로(iOS/watchOS 빌드, 로그인/산책/저장/목록, DB 마이그레이션)의 회귀 여부를 릴리즈 전 표준 절차로 점검한다.

## 2. 사전 준비
- [ ] `OpenAIConfiguration.xcconfig` 존재 및 유효 키 설정
- [ ] `supabase link` 완료(원격 project ref 연결)
- [ ] 네트워크 정상 및 패키지 의존성 resolve 완료

## 3. 빌드 체크
### 3.1 iOS
- 명령: `xcodebuild -project dogArea.xcodeproj -scheme dogArea -configuration Debug -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build`
- 기대 결과: `** BUILD SUCCEEDED **`

### 3.2 watchOS
- 명령: `xcodebuild -project dogArea.xcodeproj -scheme 'dogAreaWatch Watch App' -configuration Debug -destination 'generic/platform=watchOS' CODE_SIGNING_ALLOWED=NO build`
- 기대 결과: `** BUILD SUCCEEDED **`

## 4. 핵심 시나리오 체크
### 4.1 로그인
- [ ] Apple 로그인 성공
- [ ] 기존 사용자/신규 사용자 분기 정상 동작
- [ ] 회원가입 프로필 메시지(선택) 저장/표시 정상 동작
- [ ] 반려견 품종/나이/성별(선택) 저장/표시 정상 동작
- [ ] 기존 가입 사용자 프로필 편집(메시지/품종/나이/성별) 저장/즉시 반영 정상 동작
- [ ] 회원가입/프로필 편집 이후 profile sync outbox가 `profile -> pet` 순서로 적재됨

### 4.2 산책/기록
- [ ] 산책 시작 -> 포인트 추가 -> 종료 플로우 정상
- [ ] 시작 카운트다운 OFF: 시작 탭 후 즉시 산책 시작
- [ ] 시작 카운트다운 ON: 카운트다운 취소 시 산책 미시작
- [ ] 종료 3액션(저장하고 종료/계속 걷기/기록 폐기) 결과 정상
- [ ] 포인트 자동 기록 ON: 이동 중 자동 포인트 누적 정상
- [ ] 포인트 자동 기록 OFF: 수동 입력에서만 포인트 누적
- [ ] 앱 재실행 시 미종료 세션 복구 배너 노출(복구/폐기)
- [ ] 배터리 종료 복구 배너에서 `추정 종료` 시 제안 시각 기준으로 수동 확정 저장
- [ ] 배터리 종료 복구에서 저장 실패 시 draft 보존 + 재시도 가능
- [ ] 무이동 5분/12분/15분 단계 정책(휴식 후보/경고/자동 종료) 동작
- [ ] 자동 종료 정책은 고정(v1)이며 설정에서 비활성화되지 않음
- [ ] 설정 화면에 자동 종료 정책 단계/판정 기준 문구가 노출됨
- [ ] 저정확도/점프 GPS 샘플이 면적 계산에서 제외됨
- [ ] 산책 중 권한 강등 시 세션 안전 일시중지 + 복구 배너 노출
- [ ] 권한 거부 상태에서 복구 배너 `설정 열기` 버튼으로 시스템 설정 이동 가능
- [ ] 복구/동기화/권한 상태가 동시에 발생해도 배너 우선순위 큐에서 1개만 노출됨(P0 우선)
- [ ] 워치 중복 액션/재동기화 요청(`syncState`)에서 상태 일관성 유지
- [ ] 백그라운드 복귀 후 경과시간 표시가 wall-clock 기준으로 보정됨
- [ ] 오프라인 상태 산책 저장 후 동기화 큐 적재 확인
- [ ] 오프라인 상태에서 `오프라인 모드` 배지 노출 + 온라인 복귀 후 자동 동기화 완료 토스트 노출
- [ ] 온라인 복귀 시 큐가 `session -> points -> meta` 순서로 재전송
- [ ] 토큰 만료(401/403) 시 큐 보존 + 재인증 후 재동기화 재개
- [ ] 인증 만료 상태 복구 배너에서 `다시 로그인` 버튼으로 재인증 시트 진입 가능
- [ ] 지도 이미지 미생성 상태에서도 세션/포인트 저장 성공
- [ ] 저장 후 지도/목록 데이터 일치
- [ ] 폴리곤 1000건+ 환경에서 줌아웃 시 전체 오버레이 과밀 없이 클러스터 중심으로 표시
- [ ] LOD 모드에서 단일 클러스터(1:1) 폴리곤만 선택 렌더되고 지도 조작 지연이 완화됨
- [ ] 줌인 상태에서 폴리곤 상세 접근(탭/상세 진입) 가능
- [ ] 산책 시작 전 1탭 pet switcher로 대상 반려견 순환 변경 가능
- [ ] 산책 시작 직전 시간대/요일 기반 자동 제안이 적용되고 변경 로그가 수집됨
- [ ] 선택 반려견 변경 시 Home/WalkList 주간 통계/목록이 해당 반려견 기준으로 즉시 재집계됨
- [ ] 신규 산책 저장 시 세션 canonical pet_id가 누락되지 않음(CoreData 기준)
- [ ] 자정 걸침 세션(예: 23:50~00:20)에서 전날/오늘 면적·시간 기여가 분할 표시됨
- [ ] 타임존 변경 이벤트 후 홈 주간 집계/달력 표시가 즉시 재계산됨
- [ ] 악천후 단계에서 실외 미션이 실내 대체 미션으로 자동 치환됨
- [ ] 실내 미션 최소 행동량 미달 시 완료 확정이 거절됨
- [ ] 실내 미션이 연속 일자에 동일 템플릿으로 반복 노출되지 않음
- [ ] 전일 미완료 미션 1개가 자동 연장 슬롯으로 노출되고 보상 70%가 적용됨
- [ ] 연장 슬롯이 연속 2일 이상 자동 적용되지 않음(쿨다운/차단 메시지 확인)
- [ ] 연장 미션 미완료 시 다음날 소멸되며 추가 구제가 발생하지 않음
- [ ] 선택 반려견 전환 시 난이도 배율/행동량 목표가 해당 반려견 기준으로 즉시 재계산됨
- [ ] 저활동/고활동/노령 신호에서 목표 행동량이 정책대로 자동 조정됨
- [ ] 쉬운 날 모드(일 1회) 활성화 시 당일 보상이 20% 감액되고 2회차는 제한 처리됨
- [ ] `체감 날씨 다름` 1탭 입력 시 당일 위험도 재평가 결과가 즉시 노출됨
- [ ] 체감 피드백 주간 3회 입력 시 3회차가 제한 처리되고 잔여 횟수가 정확히 표시됨
- [ ] 체감 피드백만으로 위험도 `clear` 완전 해제가 발생하지 않음
- [ ] 라이벌 리그가 최근 14일 활동량 기준으로 `light/mid/hardcore`에 배정됨
- [ ] 리그 표본 부족 시 `effective_league` 인접 병합이 적용됨
- [ ] 리그 변동 시 사용자 안내 메시지/히스토리 데이터가 조회 가능함
- [ ] nearby 핫스팟에서 표본 미달 셀은 count가 노출되지 않고(percentile-only) 강도만 표시됨
- [ ] nearby 핫스팟에서 야간(22~06) 지연 60분 정책이 반영됨
- [ ] 민감 구역 마스킹 대상 셀이 지도 오버레이에 노출되지 않음
- [ ] 시즌 점수에서 동일 타일 30분 내 반복 이벤트가 0점 처리됨
- [ ] 시즌 점수에서 신규 경로 비율이 높을수록 보너스가 증가함
- [ ] 반복 파밍 의심 패턴에서 `score_blocked=true` + 감사 로그가 기록됨
- [ ] 72시간 비활동 복귀 세션에서 `catchup_buff_active=true` 및 +20% 신규 타일 보정이 적용됨
- [ ] 복귀 버프 주간 1회 한도 초과 시 `block_reason=weekly_limit_reached`가 기록됨
- [ ] 시즌 종료 24시간 이내 복귀 시 `block_reason=season_end_window`로 신규 지급이 차단됨

### 4.3 목록/상세
- [ ] 산책 목록 로딩 정상
- [ ] 상세 진입/이미지 저장 동작 정상
- [ ] 산책 종료 직후 공유하기 동작(텍스트+이미지) 정상
- [ ] 산책 상세 공유하기 동작(텍스트+이미지) 정상
- [ ] 지도 이미지 없음 상태에서도 텍스트 공유 가능
- [ ] 공유 카드 이미지가 1080x1080 규격으로 첨부됨
- [ ] 산책 종료 화면 `사진 찍기` 동작 후 프리뷰/공유 이미지가 촬영본 기준으로 갱신됨
- [ ] 카메라 미지원 환경에서 라이브러리 fallback이 동작함
- [ ] 가입 프로필 이미지 업로드 실패 시 복구 배너(재시도/재로그인) 동작 정상
- [ ] Home/Map/Setting/WalkList 화면 간 선택 반려견 상태가 즉시 동기화됨
- [ ] 홈에서 비활성 Picker가 제거되고 목표 카드(현재/목표/남은 면적)가 표시됨
- [ ] 목표 카드 접근성 라벨(VoiceOver) 읽기 시 핵심 값이 순서대로 전달됨
- [ ] Home/WalkList 주요 카드 상단에 `선택 반려견 기준` 배지가 노출됨
- [ ] 선택 반려견 필터 0건일 때 빈 상태 + `전체 기록 보기` CTA가 표시됨
- [ ] `전체 기록 보기` 전환 후 `기준으로 돌아가기`로 선택 반려견 필터 원복 가능
- [ ] Home 목표 카드가 `DB 비교군` 라벨 및 featured 우선 기준으로 갱신됨
- [ ] AreaDetail 비교군 카탈로그 섹션이 `sort_order/display_order/featured` 규칙대로 노출됨
- [ ] Supabase 미설정/오류 환경에서 `로컬 비교군 (Fallback)` 라벨로 정상 동작함

## 5. 마이그레이션 검증 시나리오
### 5.1 상태 확인
- 명령: `npx --yes supabase migration list`
- 기대 결과: linked 프로젝트 기준 migration state 확인 가능

### 5.2 SQL 변경 검토
- [ ] 신규 migration 파일 존재 확인
- [ ] DDL/RLS/함수 변경사항 문서와 일치
- [ ] `profiles.profile_message`, `pets.breed/age_years/gender` 컬럼 및 제약 확인
- [ ] `area_reference_catalogs` + `area_references.catalog_id/display_order/is_featured` 구조 확인
- [ ] `privacy_guard_policies/privacy_sensitive_geo_masks/privacy_guard_audit_logs` 구조 및 `rpc_get_nearby_hotspots` 확장 컬럼 확인
- [ ] `season_scoring_policies/season_tile_score_events/season_score_audit_logs/season_catchup_buff_policies/season_catchup_buff_grants` 구조 및 `rpc_score_walk_session_anti_farming` 실행 확인
- [ ] `view_weather_feedback_kpis_7d` 뷰 조회 및 지표 컬럼(`submitted/rate_limited/changed_ratio`) 확인
- [ ] `rival_league_policies/rival_league_assignments/rival_league_history` 구조 및 `rpc_refresh_rival_leagues/rpc_get_my_rival_league` 실행 확인

## 6. 배포 파이프라인 검증 시나리오
### 6.1 Workflow 정의/활성 상태
- 명령: `gh workflow list --all`
- 기대 결과:
  - `fault-injection-gate`가 `active`
  - 릴리스 배포용 workflow(`firebase-distribution*` 또는 동등 파일)가 없으면 `BLOCKED`로 기록하고 사유(계정/서명/시크릿) 명시

### 6.2 최근 실행 상태
- 명령: `gh run list --workflow fault-injection-gate.yml --limit 5`
- 기대 결과: 최신 5회 기준 `completed/success` 유지

## 7. 결과 기록 템플릿
- 실행 일시:
- 실행자:
- 대상 브랜치/커밋:

### 7.1 빌드
- iOS: `PASS | FAIL | BLOCKED`
- watchOS: `PASS | FAIL | BLOCKED`
- 근거 로그:

### 7.2 핵심 시나리오
- 로그인: `PASS | FAIL | BLOCKED`
- 산책/저장: `PASS | FAIL | BLOCKED`
- 목록/상세: `PASS | FAIL | BLOCKED`
- 근거:

### 7.3 마이그레이션
- migration list: `PASS | FAIL | BLOCKED`
- SQL 검토: `PASS | FAIL | BLOCKED`
- 근거:

### 7.4 배포 파이프라인
- workflow 정의: `PASS | FAIL | BLOCKED`
- realtime-ops-gate: `PASS | FAIL | BLOCKED`
- 최근 실행 상태: `PASS | FAIL | BLOCKED`
- 근거:

### 7.5 P0/P1 예외 게이트
- P0 fail count:
- P1 fail count:
- P1 대응 계획(담당자/일정):

### 7.6 종합 판단
- 릴리즈 가능 여부: `GO | NO-GO`
- 잔여 이슈/액션:

## 8. 배포 전/후 핵심 지표 비교
- 기준 뷰: `public.view_rollout_kpis_24h`
- 실시간 게이트 스크립트: `swift scripts/realtime_ops_rollout_gate.swift --input <kpi-json>`
- 스냅샷 수집 규칙:
  - 배포 직전 24h: `T-24h ~ T0`
  - 배포 후 24h: `T0 ~ T+24h`
- 비교 테이블:
  - `walk_save_success_rate` (목표: `>= 0.98`)
  - `watch_action_loss_rate` (목표: `<= 0.01`)
  - `caricature_success_rate` (목표: `>= 0.90`)
  - `nearby_opt_in_ratio` (관측 지표, 목표 없음)
  - `active_sessions_5m` (stage 최소치 충족)
  - `stale_ratio_5m` (목표: `< 0.12`)
  - `p95_latency_ms` (목표: `< 350`)
  - `error_rate_5m` (목표: `< 0.01`)
  - `battery_impact_percent_per_hour` (목표: `< 2.5`)
- SQL 예시:
```sql
select
  calculated_at,
  walk_save_success_rate,
  watch_action_loss_rate,
  caricature_success_rate,
  nearby_opt_in_ratio
from public.view_rollout_kpis_24h;
```

## 9. 예외 시나리오 게이트 (P0/P1)
- 참조 매트릭스: `docs/fault-injection-matrix-v1.md`
- 실행 런북: `docs/fault-injection-runbook-v1.md`
- 결과 템플릿: `docs/fault-injection-result-template-v1.md`
- [ ] P0 전 항목 PASS 확인
- [ ] P1 실패 항목은 우회/복구 전략 및 담당자/일정 명시
- [ ] 릴리즈 PR 본문에 매트릭스 링크 + 실행 결과 링크 첨부
- 자동 차단 규칙:
  - `P0 FAIL >= 1` -> `NO-GO`

## 10. 스크린샷 증적 (UI 변경 필수)
- [ ] iPhone SE 홈 스크린샷 첨부 (목표 카드 줄바꿈/겹침 없음)
- [ ] iPhone Pro Max 홈 스크린샷 첨부 (목표 카드 정보 밀도 균형 확인)
