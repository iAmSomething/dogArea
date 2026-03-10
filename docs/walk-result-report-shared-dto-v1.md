# Walk Result Report Shared DTO v1

## 연결 이슈
- #701
- #267
- #266

## 목적
- 산책 종료 직후 요약과 산책 상세 화면이 서로 다른 계산값을 읽지 않도록 `공통 결과 설명 DTO`를 고정한다.
- 숫자 계산 소스와 사용자 문구 소스를 분리해, 계산 정책이 바뀌어도 카피 계층이 직접 흔들리지 않게 한다.
- 후속 구현자가 `무엇을 집계하고`, `어떤 상태로 묶고`, `어디까지 노출하는지`를 오해 없이 바로 연결할 수 있게 만든다.

## 결론
- `산책 종료 직후`와 `산책 상세`는 같은 `WalkOutcomeExplanationDTO`를 읽는다.
- 계산 엔진이 먼저 `WalkOutcomeCalculationSnapshot`을 만든 뒤, 그 값을 기반으로 `WalkOutcomeExplanationDTO`를 조립한다.
- 화면별 차이는 DTO 자체가 아니라, DTO를 어떤 정보 밀도로 펼쳐 보이느냐에만 둔다.

## 계층 분리
### 1. 계산 스냅샷
계산 전용 원본은 `WalkOutcomeCalculationSnapshot`으로 취급한다.

포함해야 하는 값:
- 전체 포인트 수
- 반영 포인트 수
- 제외 포인트 수
- 제외 비율
- 주요 제외 사유별 카운트
- `mark` 기여값
- `route` 기여값
- 감쇠 적용값
- cap 적용값
- 기록 연결 여부
- 영역/목표 연결 메타
- 시즌 연결 메타
- 미션/퀘스트 연결 메타

이 계층은 숫자와 상태만 다룬다.

포함하지 않는 것:
- 사용자 문구
- 강조 색상
- 카드 배지명
- CTA 문장

### 2. 결과 설명 DTO
화면 공용 설명 계층은 `WalkOutcomeExplanationDTO`로 취급한다.

이 계층의 역할:
- 계산 스냅샷을 사용자가 읽을 수 있는 결과 요약으로 바꾼다.
- 종료 직후와 상세 화면이 같은 상태 분류를 읽게 만든다.
- 내부 계산 용어를 직접 노출하지 않고도, 필요한 근거는 상세에서 추적 가능하게 남긴다.

### 3. 화면별 프레젠테이션
화면별 프레젠테이션은 DTO를 소비하는 마지막 계층이다.

소비 surface:
- 종료 직후 compact 요약: `map.walk.savedOutcome.card`
- 종료 전후 연결 설명 seed: `walk.detail.valueFlow.card`
- 저장된 산책 상세 요약 anchor: `walklist.detail.loopSummary`

## Canonical DTO 초안
```swift
struct WalkOutcomeExplanationDTO {
    let summaryState: WalkOutcomeSummaryState
    let appliedPointCount: Int
    let excludedPointCount: Int
    let excludedRatio: Double
    let topExclusionReasons: [WalkOutcomeExclusionReasonSummary]
    let contribution: WalkOutcomeContributionSummary
    let connections: WalkOutcomeConnectionSummary
    let lowImpactFlag: Bool
    let copySource: WalkOutcomeCopySource
    let calculationSourceVersion: String
}
```

### 상태 분류
`summaryState`는 아래 3개만 허용한다.

- `lowApplied`
  - 사용자 문구: `거의 반영 안 됨`
  - 의미: 저장은 됐지만 실제 반영량이 매우 적다.
- `normalApplied`
  - 사용자 문구: `정상 반영`
  - 의미: 일반적인 산책 결과로 기록/영역/후속 시스템 연결이 읽힌다.
- `policyExcludedDominant`
  - 사용자 문구: `정책 제외 다수`
  - 의미: 제외 비중이 높고, 주요 제외 사유가 정책/보호/가드레일 쪽이다.

## 필드 정의
### 1. 수치 핵심
- `appliedPointCount`
  - 의미: 실제 결과 설명에 반영된 포인트 수
- `excludedPointCount`
  - 의미: 제외된 포인트 수
- `excludedRatio`
  - 의미: `excludedPointCount / totalPointCount`
  - 종료 직후는 백분율 1줄 요약, 상세는 수치와 함께 표시

### 2. 제외 사유 요약
`topExclusionReasons`는 우선순위 정렬된 최대 3개만 유지한다.

Canonical reason family:
- `accuracy_guard`
  - 사용자 문구: `정확도가 낮아 제외된 기록`
- `duplicate_or_pause`
  - 사용자 문구: `중복되거나 멈춤 구간으로 본 기록`
- `policy_guard`
  - 사용자 문구: `보호 정책으로 제외된 기록`
- `outside_session`
  - 사용자 문구: `현재 산책 구간 밖으로 판단된 기록`

각 항목은 아래 값을 가진다.
- `reasonID`
- `title`
- `count`
- `shortExplanation`

### 3. 기여 요약
`contribution`은 계산 근거를 상세 화면에서 읽기 위한 구조다.

포함 값:
- `markContribution`
- `routeContribution`
- `decayAppliedValue`
- `capAppliedValue`

규칙:
- 종료 직후에는 이 내부 용어를 직접 노출하지 않는다.
- 상세 화면에서는 `영역 표시 기여`, `경로 기여`, `감쇠 적용`, `상한 적용`처럼 번역된 라벨만 쓴다.
- raw engine 용어는 디버그 로그나 개발자 문서에만 남긴다.

### 4. 연결 메타
`connections`는 `이 산책이 어디에 이어지는가`를 설명하는 계층이다.

포함 값:
- `recordConnection`
  - 저장 여부, 기록 허브 재진입 경로
- `territoryConnection`
  - 영역/목표 반영 여부, 다음 목표 해석 연결
- `seasonConnection`
  - 시즌 반영 여부, 점령/유지 해석 연결
- `questConnection`
  - 미션/퀘스트 반영 여부, 진행 연결 또는 반영 없음

각 연결 항목은 공통으로 아래 값을 가진다.
- `status`
  - `updated`
  - `pending`
  - `notApplicable`
- `headline`
- `detail`

## 계산 소스와 카피 소스 분리
### 계산 소스
- exclusion ratio 산출
- 주요 제외 사유 집계
- mark/route/감쇠/cap 계산
- 연결 대상의 실제 반영 여부 판정

### 카피 소스
- `거의 반영 안 됨`, `정상 반영`, `정책 제외 다수` 상태명
- 제외 사유 제목과 짧은 해설
- 연결 흐름 설명
- 종료 직후 요약 한 줄

원칙:
- 계산 소스는 숫자와 enum만 반환한다.
- 카피 소스는 계산 결과를 받아 사용자 문장을 조립한다.
- 같은 계산값이라도 종료 직후와 상세 화면의 밀도만 다르고 핵심 문장은 바뀌지 않는다.

## Edge Case
### 거의 반영 안 됨
다음 상황은 `lowApplied`로 수렴시킨다.
- 반영 포인트 수가 극히 적음
- 제외 비율이 높음
- 연결 메타가 대부분 `pending` 또는 `notApplicable`

이 상태에서도 유지할 것:
- 저장 자체는 되었는지
- 가장 큰 제외 사유가 무엇인지
- 다시 확인할 화면이 어디인지

### 정책 제외 다수
다음 상황은 `policyExcludedDominant` 우선으로 본다.
- 제외 비율이 높고
- 상위 reason이 `policy_guard` 계열이며
- 사용자가 `왜 적게 반영됐는지`를 먼저 이해해야 하는 경우

### 정상 반영
아래 조건이면 `normalApplied`로 본다.
- 반영 포인트 수가 의미 있게 남고
- 제외 사유가 일부 있더라도 결과 흐름을 가리지 않으며
- 영역/시즌/미션 중 적어도 하나 이상이 `updated`로 읽히는 경우

## 화면별 사용 규칙
### 종료 직후
- `appliedPointCount`
- `excludedRatio`
- 최상위 reason 1개
- 연결 메타 1줄

### 상세 화면
- `appliedPointCount`
- `excludedPointCount`
- `excludedRatio`
- 상위 reason 최대 3개
- contribution 4종
- connections 전체

## 비범위
- 점수 계산 엔진 구현
- exclusion threshold 수치 확정
- UI 컴포넌트 최종 시각안

## 회귀 체크
- `swift scripts/walk_result_report_shared_dto_unit_check.swift`
