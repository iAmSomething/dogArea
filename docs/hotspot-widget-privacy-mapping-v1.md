# 핫스팟 위젯 프라이버시 매핑 v1

- 대상 이슈: #218
- 연결 이슈: #45
- 연결 에픽: #214
- 목적: 위젯/앱 상세 경로에서 `privacy_mode` + `suppression_reason` 표현을 동일 정책으로 고정한다.

## 1. 노출 원칙

1. 위젯에는 사용자 좌표, 정밀 위치, 개별 핫스팟 카운트를 노출하지 않는다.
2. 위젯에는 `높음/보통/낮음/없음` 단계와 정책 안내 카피만 노출한다.
3. 비회원은 개인화 주변 신호 대신 기능 소개형 카드만 노출한다.
4. `delay`가 적용된 경우 지연 분(minute)만 안내하고 원시 시계열은 노출하지 않는다.

## 2. 서버 정책 매핑표

| privacy_mode | suppression_reason | 위젯 상태 | 사용자 카피 | 노출 제한 |
| --- | --- | --- | --- | --- |
| `full` | `null` | `memberReady` | 개인 식별 정보 없이 익명 활성도 단계만 표시 | 좌표 미노출, 정밀 카운트 미노출 |
| `percentile_only` | `k_anon` | `privacyGuarded` | k-익명 정책으로 백분위 단계만 제공 | 좌표 미노출, 정밀 카운트 미노출 |
| `guarded` | `sensitive_mask` | `privacyGuarded` | 민감 지역은 마스킹되어 상세 신호 제한 | 좌표 미노출, 정밀 카운트 미노출 |
| `none` | `no_hotspot` | `emptyData` | 주변 익명 핫스팟 신호가 충분하지 않음 | 좌표 미노출 |
| `none` | `location_unavailable` | `emptyData` | 최근 위치 기반 데이터가 없어 안내 카드 표시 | 좌표 미노출 |
| `guest` | `guest_mode` | `guestLocked` | 로그인 후 익명 트렌드 기능 활성화 가능 | 개인화 신호 미노출 |

## 3. 앱 상세/위젯 정합 규칙

1. 정책 분기 키는 서버 원문(`privacy_mode`, `suppression_reason`)만 사용한다.
2. `k_anon`, `sensitive_mask`, `delay` 문구는 위젯/앱 상세에서 동일 의미를 유지한다.
3. 정책 미지원 값은 `privacyGuarded` + 일반 보호 문구로 폴백한다.

## 4. QA 체크포인트

1. 회원 정상 지역: 단계 배지 노출, 좌표/개별 카운트 미노출.
2. `k_anon` 지역: 백분위 문구 노출, 상세 수치 미노출.
3. `sensitive_mask` 지역: 민감 마스킹 문구 노출.
4. 비회원: 로그인 유도 + 기능 소개 카드 노출.
5. 야간 지연 구간: `정책 지연 n분` 문구 노출.
