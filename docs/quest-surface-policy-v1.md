# Quest Surface Policy v1

## 1. 목적
- 산책 중 자동 추적 가능한 퀘스트와 홈 전용 수동 미션의 경계를 먼저 고정한다.
- 홈/지도/위젯이 같은 퀘스트 상태를 서로 다르게 해석하지 않도록 source of truth를 정의한다.
- 후속 이슈 `#465`, `#467`, `#468`이 같은 정책 위에서 HUD/토스트/배너 우선순위를 구현할 수 있게 한다.

## 2. 표면별 source of truth
| surface | primary role | source of truth | 비고 |
| --- | --- | --- | --- |
| `home` | 실내/수동 미션 체크, 보상 수령, 상세 설명 | `IndoorMissionBoard` | 현재 앱의 실내 미션 체크 흐름을 유지한다. |
| `map` | 산책 중 자동 추적 진행 피드백 | server canonical quest summary | 지도는 산책 중 자동 추적 가능한 상태만 올린다. |
| `widget` | 짧은 진행률/보상 가능 상태 확인 | server canonical quest summary mirror | 위젯은 지도/홈을 대신 판단하지 않고 mirror 역할만 한다. |

## 3. 지도에 기본 노출 가능한 자동 추적 조건
아래 조건만 `산책 중 Companion HUD` 기본 노출 후보로 취급한다.

| rule | counting rule | exclusion rule |
| --- | --- | --- |
| `walk_duration` | 산책 세션이 실제 walking 상태일 때만 누적 | 일시정지, 종료 확인, 복구 대기 구간 제외 |
| `walk_distance` | 유효 위치 샘플 간 거리만 누적 | 정지 드리프트, 낮은 정확도 샘플 제외 |
| `new_tile` / `new territory tile` | 신규 타일/영역 점령 시만 증가 | 이미 점령한 타일 재방문 제외 |
| `active_walking_time` | 정지 구간을 제외한 active walking 시간만 집계 | 휴식 후보, 자동 종료 경고, 복구 지연 구간 제외 |

### 3.1 자동 추적 후보가 아닌 항목
아래 항목은 자기 보고 또는 실내 행위 성격이 강하므로 지도 HUD 기본 노출 대상이 아니다.
- `recordCleanup`
- `petCareCheck`
- `trainingCheck`
- 사진 정리, 브러싱, 물 챙김, 컨디션 체크, 실내 훈련 같은 home checklist 류

정책상 이들은 `home only manual checklist` 버킷으로 유지한다.

## 4. 대표 미션 선택 규칙
지도 HUD에는 `대표 1개 + 추가 n개` 구조만 허용한다.

우선순위는 아래 순서다.
1. `claimable == true`
2. 자동 추적 가능 + 진행률 `85% 이상`
3. 자동 추적 가능 + 진행률 높은 순
4. 자동 추적 불가지만 summary-only로 알려야 하는 상태

대표 후보가 없으면 지도는 quest HUD를 비우거나 empty state만 노출한다.

## 5. 지도/홈/위젯의 역할 경계
### 5.1 Home
- 실내/수동 미션 체크리스트의 primary surface
- 완료 확인 및 보상 수령의 canonical surface
- 자동 미션은 필요 시 보조 요약으로만 설명

### 5.2 Map
- `산책 중 실제로 자동 추적 가능한 항목`만 HUD/토스트 후보
- 실내/자기보고형 미션은 지도에 올리지 않음
- 완료 시점에는 `보상 가능`까지만 알림
- 즉시 수령은 하지 않고 홈 퀘스트 보드 또는 관련 상세 화면으로 유도

### 5.3 Widget
- server canonical quest summary의 mirror
- 진행률/보상 가능 상태 확인 + 앱 진입 요청만 담당
- widget가 home/manual mission semantics를 새로 정의하지 않음

## 6. 보상 흐름 정책
지도/위젯에서 허용하는 최종 상태는 `보상 가능`까지다.

| surface | allowed action |
| --- | --- |
| `map` | 보상 가능 알림, 홈/퀘스트 보드 진입 유도 |
| `widget` | 보상 가능 표시, 앱 라우트 요청 |
| `home` | 실제 claim 수행, 완료 상태 반영 |

즉시 수령을 지도에서 허용하지 않는 이유:
- 산책 흐름을 끊는다.
- 다중 미션/다중 보상 처리 시 오류 복구가 복잡해진다.
- `critical banner`, `watch sync`, `offline recovery`와 충돌 가능성이 크다.

## 7. 상태 표현 충돌 방지 규칙
- `home`의 실내 미션 완료와 `map/widget`의 자동 퀘스트 완료는 서로 다른 surface role로 유지한다.
- `map`과 `widget`은 같은 server canonical summary를 사용하므로, 같은 quest instance에 대해 다른 completion 의미를 만들지 않는다.
- `home`은 실내 체크/수동 보상 흐름을 담당하되, 자동 퀘스트 요약을 참고 정보로만 소비한다.

## 8. QA 시나리오
### 8.1 단일 산책 자동 미션
- 조건: `walk_duration` 1개 active, 진행률 40%
- 기대: 지도 대표 HUD 1개, 홈은 실내 미션 흐름 유지, 위젯은 동일 진행률 mirror

### 8.2 다중 자동 미션
- 조건: `walk_duration 70%`, `new_tile 90%`, `active_walking_time 20%`
- 기대: 지도는 `new_tile`을 대표로 선택, 나머지는 `추가 n개`

### 8.3 실내 미션 혼합
- 조건: `recordCleanup`, `petCareCheck` active + `walk_duration` 55%
- 기대: 지도는 `walk_duration`만 노출, 홈은 실내 체크리스트 유지

### 8.4 보상 가능 상태
- 조건: server canonical quest가 `completed + claimable`
- 기대: 지도/위젯은 `보상 가능`까지만 노출, claim은 홈에서 처리

## 9. 구현 인계
- `#465`: HUD + milestone toast + expandable checklist는 본 문서의 자동 추적 규칙과 대표 미션 규칙을 그대로 사용한다.
- `#467`: collapsed/expanded 최소 정보셋은 본 문서의 대표 1개 + 추가 n개 규칙을 전제로 한다.
- `#468`: critical banner 우선순위와 quest HUD 공존 규칙은 본 문서의 `map = progress feedback only` 경계를 침범하지 않아야 한다.

## 10. 코드 기준점
- 정책 모델: `dogArea/Source/Domain/Quest/Models/QuestSurfacePolicyModels.swift`
- 정책 서비스: `dogArea/Source/Domain/Quest/Services/QuestSurfacePolicyService.swift`
