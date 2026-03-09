# Walk Live Activity Copy And Timer v1

- Issue: #616
- Scope: `WalkLiveActivityWidget`, lock screen, expanded Dynamic Island, compact/minimal surfaces

## 1. Canonical Rule

1. Live Activity의 상태 해석은 `autoEndStage`를 우선한다.
2. `pointCount == 0` 또는 `capturedAreaM2 == 0`만으로 진행 headline을 결정하지 않는다.
3. 종료 상태(`ended`)에서는 진행 중 headline/detail을 절대 재사용하지 않는다.

## 2. Stage Copy Contract

### `active`
- headline: 진행 상황 중심
- detail: 포인트/영역 증가 설명
- badge: `정상 기록 중`

### `restCandidate`
- headline: 휴식 감지 확인
- detail: 다시 움직이면 정상 상태로 복귀한다는 안내
- badge: `휴식 감지`

### `warning`
- headline: 자동 종료 임박
- detail: 움직이지 않으면 종료 단계로 넘어간다는 안내
- badge: `자동 종료 경고`

### `autoEnding`
- headline: 종료 직전/정리 중
- detail: 앱에서 세션 상태 확인 안내
- badge: `자동 종료 단계`

### `ended`
- headline: `산책이 종료되었어요`
- detail: 저장 결과 또는 앱 확인 안내
- badge: `산책 종료`

## 3. Timer Contract

1. `active`, `restCandidate`, `warning`, `autoEnding`은 self-updating timer 스타일을 사용한다.
2. `ended`는 마지막 확정 경과 시간을 frozen text로 표시한다.
3. lock screen metric tile과 Dynamic Island compact leading은 같은 elapsed presentation을 사용한다.

## 4. Surface Consistency

1. lock screen headline/detail/badge
2. expanded Dynamic Island bottom detail/badge
3. compact trailing text
4. minimal symbol

모든 표면은 같은 `autoEndStage` 해석 원칙을 공유해야 한다.

## 5. Forbidden

1. 종료 상태에서 `첫 포인트를 기다리고 있어요` 같은 진행 중 문구를 노출하지 않는다.
2. 경과시간을 모든 단계에서 정적 문자열로만 렌더하지 않는다.
3. 표면마다 서로 다른 상태 우선순위를 사용하지 않는다.
