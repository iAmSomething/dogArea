# Quest Stage1 Template & Difficulty Policy v1

## 1. 목적
- 일일/주간 퀘스트를 사용자 활동량에 맞춰 안정적으로 생성한다.
- 퀘스트 정책 문서만으로 동일 입력에서 동일 결과를 재현할 수 있게 한다.

## 2. 퀘스트 타입 정의 (Quest DSL v1)
| type | 설명 | 기본 단위 | 완료 판정 기준 |
| --- | --- | --- | --- |
| `new_tile` | 신규 타일 개척 | tile count | 기준 시간창 내 신규 타일 수 달성 |
| `linked_path` | 연속 경로 연결 | segment count | 연속 경로 길이/연결 수 달성 |
| `walk_duration` | 산책 시간 달성 | minute | 단일 또는 누적 산책 시간 달성 |
| `streak_days` | 연속일 유지 | day | 연속 산책 일수 달성 |

## 3. 난이도 티어 및 보상 계수
| tier | 목표 계수(베이스 대비) | 시즌 점수 계수 | 꾸미기 토큰 |
| --- | --- | --- | --- |
| `Easy` | 0.8x | 1.0x | +5 |
| `Normal` | 1.0x | 1.2x | +8 |
| `Hard` | 1.25x | 1.5x | +12 |

### 3.1 활동량 버킷
- 저활동(`low`): 최근 7일 일평균 이벤트 수 하위 30%
- 중활동(`mid`): 최근 7일 일평균 이벤트 수 31~70%
- 고활동(`high`): 최근 7일 일평균 이벤트 수 상위 30%

### 3.2 목표값 계산 규칙
1. `base_target = percentile(activity_7d, 50)`
2. `bucket_adjust = {low: -15%, mid: 0%, high: +20%}`
3. `tier_adjust = {Easy: 0.8, Normal: 1.0, Hard: 1.25}`
4. `final_target = clamp(round(base_target * (1 + bucket_adjust) * tier_adjust), min, max)`

## 4. 생성 규칙
- 일일 퀘스트 3개: `Easy 1`, `Normal 2`
- 주간 퀘스트 2개: `Normal 1`, `Hard 1`
- 생성 시점 스냅샷: 생성된 인스턴스는 목표값 snapshot 고정
- 무료 reroll: 일일 퀘스트 1일 1회 무료

## 5. 중복/불가능 퀘스트 방지 규칙
### 5.1 반복 출현률 제한
- 한 사용자 기준 최근 5개 일일 슬롯에서 동일 `type`은 최대 2회
- 동일 날 3개 슬롯 내 동일 `type` 중복 금지

### 5.2 불가능 조건 필터
- 날씨 차단: 악천후 단계에서 실외 의존 퀘스트(`new_tile`, `linked_path`) 제외
- 권한 차단: 위치 권한 미허용 상태에서 위치 의존 퀘스트 제외
- 활성 펫 차단: `selectedPetId` 부재 시 펫 기준 퀘스트 제외

## 6. 대체 퀘스트 슬롯 정의
| slot reason | 기존 후보 | 대체 후보 | 만료 |
| --- | --- | --- | --- |
| weather_blocked | `new_tile`, `linked_path` | `walk_duration` | 당일 23:59 |
| permission_blocked | 위치 의존 전체 | `walk_duration`, `streak_days` | 권한 복구 또는 당일 종료 |

- 대체 슬롯은 원본 슬롯 ID를 유지하고 `status=alternative` 상태 전이만 수행한다.
- 대체 슬롯은 보상 계수를 하향하지 않는다(실패 경험 완충 목적).

## 7. 재현 가능한 생성 예시
### 7.1 저활동 사용자 일일 3개 예시
- 입력: `activity_7d_avg=18`, `bucket=low`, `seed=20260301`
- 출력:
  1. `Easy/walk_duration/target=14m`
  2. `Normal/new_tile/target=5`
  3. `Normal/streak_days/target=2`

### 7.2 고활동 사용자 일일 3개 예시
- 입력: `activity_7d_avg=82`, `bucket=high`, `seed=20260301`
- 출력:
  1. `Easy/new_tile/target=9`
  2. `Normal/linked_path/target=7`
  3. `Normal/walk_duration/target=40m`

### 7.3 reroll 예시
- 입력: 동일 seed, `reroll_count_today=0`
- 결과: 기존 슬롯과 동일 `type` 재등장 금지 + 불가능 조건 필터 재평가

## 8. 수용 기준 매핑
- 활동량 상/중/하 사용자 난이도 편차 허용 범위: 7일 평균 기반 버킷 보정 + min/max clamp
- 동일 타입 반복 출현률 제한 규칙 충족: 최근 5슬롯 2회 상한 + 당일 중복 금지
- 정책 문서만으로 예시 퀘스트 재현 가능: seed/입력/출력 표준화

## 9. Stage2 인계 항목
- 스키마: `quest_templates`, `quest_instances`, `quest_progress`, `quest_claims`
- 상태 전이: `generated -> active -> completed -> claimed | expired | alternative`
- 서버 강제 규칙: reroll 1일 1회, 목표 snapshot 고정, 멱등 진행도 집계
