# Weather Risk Provider Policy v1 (Issue #133)

## 1. 목표
- 날씨 리스크 판정을 재현 가능한 규칙으로 표준화한다.
- Provider 장애/지연 상황에서도 퀘스트/스트릭 UX가 끊기지 않도록 fallback 체계를 정의한다.

## 2. Provider 어댑터 설계
- Primary Provider: Open-Meteo 기반(격자 예보)
- Secondary Provider: Meteostat 또는 동일 스키마 어댑터
- 계약(공통 DTO):
  - `gridKey` (원본 좌표 저장 금지)
  - `observedAt` (UTC epoch)
  - `precipitationMMPerHour`
  - `temperatureC`
  - `windMps`
  - `confidence` (`high|medium|low`)

Adapter 규칙:
- Primary timeout/5xx/스키마 오류 시 Secondary 재시도
- 둘 다 실패 시 마지막 정상 캐시 + 보수적 판정

## 3. 리스크 단계 v1
- `clear` (정상)
- `caution` (주의)
- `bad` (위험)
- `severe` (고위험)

판정 입력 지표:
- 강수 (`mm/h`)
- 고온/저온 (`°C`)
- 풍속 (`m/s`)

기본 임계값(운영 시작값):
- 강수:
  - `>= 12`: severe
  - `>= 6`: bad
  - `>= 1`: caution
- 기온:
  - `>= 33` 또는 `<= -8`: severe
  - `>= 30` 또는 `<= -3`: bad
  - `>= 28` 또는 `<= 0`: caution
- 풍속:
  - `>= 14`: severe
  - `>= 10`: bad
  - `>= 6`: caution

최종 리스크:
- 지표별 리스크의 `최댓값`을 사용
- 동일 입력은 항상 동일 결과(결정적 함수)

## 4. 시간대/지역 규칙
- 사용자 로컬 타임존의 현재 시각을 기준으로 가장 가까운 1시간 슬롯 예보를 선택
- 지역 식별은 좌표 자체가 아닌 `gridKey(geohash7)` 사용
- 저장/로그에 원본 위경도는 남기지 않는다

## 5. fallback/지연 정책
- 요청 타임아웃: `2.5s`
- 재시도: Primary 1회, Secondary 1회
- API 실패 시 동작:
  1. `cache_age <= 2h`: 캐시값 사용
  2. `cache_age > 2h`: `clear`로 강등하지 않고 최소 `caution` 유지
- fallback 상태는 UI에 명시적으로 표기 (`Fallback` 배지)

## 6. 캐시 TTL/신뢰도 로그
- 데이터 갱신 주기: `1h`
- 캐시 TTL: `2h`
- cache TTL: `2h`
- 로그 필드:
  - `provider` (`primary|secondary|cache|fallback`)
  - `latencyMs`
  - `gridKey`
  - `riskLevel`
  - `confidence`
  - `cacheAgeSec`
  - `decisionReason`

## 7. QA 재현 시나리오
1. 강우/폭염/한파/강풍 각각 단일 지표로 리스크 상승 검증
2. Primary timeout + Secondary 성공 시 Secondary 판정 사용 확인
3. Provider 모두 실패 + 캐시 90분: 캐시 판정 사용 확인
4. Provider 모두 실패 + 캐시 3시간: `caution` 이상 보수 판정 확인
5. 동일 입력 100회 반복 시 동일 결과 확인

## 8. Stage 연결
- Stage 2(#134): 위 정책을 엔진/스토어에 반영하고 Shield 집계와 결합
- Stage 3(#135): 사용자 안내/접근성/fallback 배지 UX 반영 (완료)
