# Rival Tab UX Usecase Spec v1.1

## 1. 목적
- 5탭 IA(`홈 / 산책 목록 / 지도 / 라이벌 / 설정`)에서 `라이벌` 탭의 역할을 명확히 정의한다.
- 기능을 "화면 단위"가 아니라 "행동 단위"로 분해해, 구현/QA/분석 이벤트를 일치시킨다.
- 개인정보 최소 노출(익명 핫스팟)을 기본으로, 사용자 동의를 선행 조건으로 강제한다.

## 2. 범위
### In Scope
- 라이벌 탭 정보 구조와 화면 전환 규칙
- 익명 핫스팟(근처 사용자 밀집도) 조회/노출
- 동의/비동의 상태 전환 UX
- 기본 리더보드/매칭 진입 슬롯(스켈레톤)
- 오류/오프라인/권한 거부 처리 UX

### Out of Scope
- 실시간 PvP
- 개인 식별 가능한 지도 노출(닉네임/강아지명/실좌표)
- 친구 그래프/팔로우 관계

## 3. 핵심 원칙
1. 프라이버시 우선: 기본값 `비공개`.
2. 기능 우선순위: 기록(지도) > 분석(홈/목록) > 경쟁(라이벌).
3. 단일 행동 단위: 한 화면에서 한 번에 한 의사결정.
4. 실패해도 길이 남는다: 에러 상태에서 다음 액션 버튼을 항상 제공.
5. 캐리커처는 프로필 맥락 유지: 라이벌 탭에서 캐리커처 생성 기능 미노출.

## 4. 사용자 상태 모델
### 인증 상태
- `guest`: 라이벌 탭 읽기 제한 + 가입 유도.
- `member`: 라이벌 탭 전체 접근 가능.

### 위치 공유 상태
- `sharing_off`: 핫스팟 송신/집계 참여 모두 비활성.
- `sharing_on`: 산책 중 30초 간격 presence 송신 + 집계 반영.

### 위치 권한 상태(iOS)
- `authorized`: 핫스팟 조회 가능.
- `denied/restricted`: 핫스팟 조회 불가, 권한 안내 카드 노출.

### 네트워크 상태
- `online`: 원격 조회 + 캐시 갱신.
- `offline`: 마지막 캐시 스냅샷 노출 + stale 안내.

## 5. 5탭 IA 규칙
1. 홈: 통계/목표/요약.
2. 산책 목록: 기록 조회/상세.
3. 지도: 산책 기록 생성(Primary).
4. 라이벌: 익명 비교/핫스팟/경쟁 허브.
5. 설정: 계정/프로필/권한/캐리커처 관리.

### 탭 전환 규칙
- 지도 산책 진행 중 라이벌 탭 진입 시: 기록은 유지, 라이벌은 읽기 전용.
- 라이벌 탭에서 위치 공유 토글 변경 시: 즉시 저장 + 토스트.
- 게스트가 라이벌 탭 핵심 기능 탭 시: 업그레이드 시트 표시.

## 6. 라이벌 탭 정보 구조
## 6.1 상단 영역
- 타이틀: `라이벌`
- 보조 문구: `근처 산책 열기를 익명으로 확인해요`
- 상태 배지:
  - `비공개`
  - `공유 중`
  - `권한 필요`

## 6.2 본문 카드 순서
1. 프라이버시/동의 카드
2. 익명 핫스팟 카드
3. 리더보드 요약 카드(Phase 2 실데이터, Phase 1 스켈레톤)
4. 라이벌 매칭 카드(Phase 2 실동작, Phase 1 준비중)

## 6.3 하단 액션
- `설정에서 상세 관리` (설정 > 위치 공유 섹션 deep link)

## 7. 유스케이스 정의
## UC-01 라이벌 탭 첫 진입 (회원, 공유 OFF)
### 사전 조건
- 사용자: `member`
- `location_sharing_enabled = false`

### 사용자 액션/시스템 동작
1. 사용자가 라이벌 탭 탭.
2. 시스템이 상태 로드:
   - auth 세션
   - 공유 토글 상태
   - 위치 권한 상태
3. 화면 노출:
   - 프라이버시 카드: `현재 비공개`
   - CTA: `익명 공유 시작`
   - 핫스팟 카드는 잠금형 안내(`동의 후 이용 가능`)

### 성공 기준
- 사용자는 "무엇이 잠겨 있고 어떻게 열리는지" 3초 내 이해 가능.

## UC-02 익명 공유 시작(동의 플로우)
### 트리거
- `익명 공유 시작` 버튼 탭

### 모달 시트 구성
1. 제목: `익명 위치 공유 동의`
2. 설명:
   - 닉네임/강아지명/정밀좌표는 표시되지 않음
   - 10분 TTL 집계
   - 언제든 설정에서 해제 가능
3. 체크박스:
   - `내용을 이해했습니다`
4. 버튼:
   - `취소`
   - `동의하고 시작` (체크 전 비활성)

### 시스템 처리
1. 동의 확인 시 `location_sharing_enabled=true` 저장.
2. 산책 중이면 즉시 presence 송신 스케줄러 활성화.
3. 토스트: `익명 공유가 시작됐어요`.

### 예외
- 저장 실패: `설정 반영 실패, 다시 시도해주세요`.

## UC-03 핫스팟 조회 (공유 ON, 권한 허용)
### 주기
- 진입 즉시 1회
- 이후 10초 간격 갱신
- 앱 백그라운드 진입 시 폴링 중지, 복귀 시 재개

### 조회 조건
- 위치 권한 `authorized`
- 네트워크 `online`

### 화면 규칙
1. 지도/미니맵 위 익명 버블 오버레이
2. 버블 텍스트:
   - `가까운 산책 열기 높음`
   - `활발`
   - `보통`
3. 개별 사용자 식별 정보 없음

### 성능 예산
- 첫 렌더 1.2초 이내
- 재조회 반영 10초 이내

## UC-04 위치 권한 거부 상태
### 조건
- iOS 위치 권한 `denied/restricted`

### UX
1. 핫스팟 카드 대신 권한 안내 카드 노출
2. 문구:
   - `근처 익명 핫스팟을 보려면 위치 권한이 필요해요`
3. 버튼:
   - `설정 열기`
   - `나중에`

### 시스템 액션
- `설정 열기` 탭 시 `UIApplication.openSettingsURLString`.

## UC-05 오프라인/서버 에러
### 오프라인
- 캐시 있으면 마지막 스냅샷 노출 + `마지막 업데이트 HH:mm`
- 캐시 없으면 빈 상태 + `네트워크 연결 후 다시 시도`

### 서버 에러
- 5xx: `일시적으로 불안정해요. 잠시 후 다시 시도해주세요.`
- 401/403: 인증 만료 배너 + 재로그인 유도
- 429: `요청이 많아요. 잠시 후 다시 시도해주세요.`

## UC-06 게스트 사용자 진입
### UX
1. 라이벌 탭 진입 시 요약 미리보기만 노출
2. 핵심 CTA:
   - `로그인하고 라이벌 시작`
3. 부가 안내:
   - `익명 기반이라 개인정보는 노출되지 않아요`

### 액션
- CTA 탭 -> 기존 `AuthFlowCoordinator` 업그레이드 시트 호출.

## UC-07 산책 중 라이벌 탭 전환
### 조건
- 지도에서 산책 진행 중

### 규칙
1. 라이벌 탭 이동 가능
2. 하단 상태바 노출:
   - `산책 기록 중 · 지도에서 종료 가능`
3. 라이벌 탭에서 산책 종료 버튼은 제공하지 않음(지도에서만 종료)

### 의도
- 기록 제어 책임을 지도에 고정해 실수 종료 방지.

## UC-08 라이벌 리더보드 요약 (Phase 2)
### 카드 구성
1. 주간 티어
2. 내 순위 범위(정확 순위 대신 구간 가능)
3. 이번 주 기여 횟수
4. CTA: `전체 보기`

### 프라이버시 규칙
- 개인 상대의 정확 이동 경로/좌표는 노출 금지.

## UC-09 신고/차단 진입 (Phase 2)
### 진입
- 리더보드/상대 카드의 `...` 메뉴

### 선택지
- `신고`
- `숨기기`

### 처리
- 로컬 즉시 반영 + 서버 비동기 처리
- 실패 시 롤백 토스트 제공

## 8. 컴포넌트/상태 상세
## RivalPrivacyCard
- 상태:
  - off / on / error
- 액션:
  - on 전환
  - off 전환
- 부가:
  - 마지막 변경 시각 표시

## NearbyHotspotCard
- 상태:
  - loading / ready / empty / permissionDenied / offline / error
- ready 표시:
  - 핫스팟 개수
  - 최고 강도 버킷
  - 마지막 갱신 시각

## RivalLeaderboardCard
- 상태:
  - skeleton(Phase1)
  - ready(Phase2)
  - error

## 9. 카피 가이드
1. "익명" 단어를 동의/상태/오류 문구에 반복 사용.
2. "개인정보 노출 없음"을 초기 진입 문구에 고정 배치.
3. 실패 문구는 원인 + 다음 행동을 함께 제공.

## 10. 접근성
1. 카드/버튼 VoiceOver label 명시.
2. 색상만으로 상태 구분 금지(텍스트 배지 동시 제공).
3. 동의 시트 핵심 문구는 Dynamic Type 대응.

## 11. 분석 이벤트
1. `rival_tab_viewed`
2. `rival_privacy_opt_in_started`
3. `rival_privacy_opt_in_completed`
4. `rival_hotspot_fetch_succeeded`
5. `rival_hotspot_fetch_failed`
6. `rival_permission_prompt_opened`
7. `rival_guest_upgrade_clicked`
8. `rival_leaderboard_opened`

## 12. Feature Flag
1. `ff_rival_tab_v1` (탭 노출)
2. `ff_nearby_hotspot_v1` (핫스팟 조회)
3. `ff_rival_leaderboard_v1` (리더보드)
4. `ff_rival_report_block_v1` (신고/차단)

## 13. QA 체크리스트
1. 공유 OFF 상태에서 presence 미송신 확인.
2. 공유 ON 후 30초 간격 송신 확인.
3. 권한 거부 시 핫스팟 비노출 확인.
4. 오프라인 캐시 fallback 동작 확인.
5. 게스트 진입 시 업그레이드 유도 동작 확인.
6. 산책 중 탭 전환 시 기록 세션 유지 확인.

## 14. 오픈 이슈
1. 리더보드 표기 단위: 정확 순위 vs 퍼센타일.
2. 라이벌 매칭 최소 표본 수(프라이버시 임계치).
3. 신고 카테고리 세분화 수준.

## 15. 상태 전이 정의(핵심)
## 15.1 공유 상태 전이
| 현재 상태 | 트리거 | 다음 상태 | 즉시 액션 | 실패 시 |
|---|---|---|---|---|
| off | 동의 시트 완료 | on | 토글 저장, 송신 스케줄 활성화, 토스트 | off 유지 + 에러 토스트 |
| on | 공유 중지 탭 | off | 토글 저장, 송신 스케줄 중지 | on 유지 + 에러 토스트 |
| on | 로그아웃 | off | 로컬 토글 강제 off, 송신 정지 | 로그인 화면 우선 |
| off/on | 앱 재실행 | persisted | 저장된 토글 복원 | 기본값 off |

## 15.2 화면 상태 전이
| 상태 키 | 진입 조건 | 표시 화면 | 사용자 액션 |
|---|---|---|---|
| `guest_locked` | guest | 가입 유도 카드 | 로그인/회원가입 |
| `permission_required` | member + 권한거부 | 권한 요청 카드 | 설정 열기 |
| `consent_required` | member + sharing_off + 권한허용 | 익명 동의 카드 | 동의 시트 |
| `hotspot_ready` | member + sharing_on + online | 핫스팟 카드 | 새로고침/지도보기 |
| `offline_cached` | member + offline + cache | 캐시 카드 | 재시도 |
| `offline_empty` | member + offline + no cache | 빈상태 카드 | 재시도 |
| `error_retryable` | member + server error | 에러 카드 | 재시도 |

## 16. CTA 동작 명세(버튼 단위)
## CTA-01 `익명 공유 시작`
1. 사전검증: `member` 여부, 위치 권한 상태.
2. 권한 미허용이면 동의 시트가 아니라 권한 카드로 리다이렉트.
3. 권한 허용이면 동의 시트 오픈 + 이벤트 `rival_privacy_opt_in_started`.
4. 시트 완료 시 저장 성공:
   - `location_sharing_enabled=true`
   - 이벤트 `rival_privacy_opt_in_completed`
   - 토스트 `익명 공유가 시작됐어요`
5. 저장 실패:
   - 이벤트 `rival_privacy_opt_in_failed`
   - 토스트 `설정 반영 실패, 다시 시도해주세요`

## CTA-02 `공유 중지`
1. 확인 다이얼로그 없이 즉시 해제(빠른 복구 우선).
2. `location_sharing_enabled=false` 저장.
3. presence 송신 작업 즉시 cancel.
4. 토스트 `익명 공유를 중지했어요`.

## CTA-03 `새로고침`
1. 중복 탭 방지(로딩 중 disabled).
2. 3초 타임아웃.
3. 실패 시 retry 버튼 유지 + 마지막 성공시각 보존.

## CTA-04 `설정 열기`
1. iOS 시스템 설정 deep link 실행.
2. 복귀 시 권한 상태 재평가.

## CTA-05 `로그인하고 라이벌 시작`
1. `AuthFlowCoordinator.requestAccess(.cloudSync)` 호출.
2. 성공 시 인증 화면 전환.
3. 취소 시 라이벌 탭 스냅샷 상태 유지.

## 17. 데이터 계약(UX-의존 필드)
## 17.1 로컬 상태
- `location_sharing_enabled: Bool`
- `last_hotspot_fetch_at: TimeInterval?`
- `last_hotspot_fetch_error: String?`
- `hotspot_cache_version: String`

## 17.2 서버 응답 계약(핫스팟)
```json
{
  "center_geohash": "wydm123",
  "generated_at": "2026-03-01T12:00:00Z",
  "cells": [
    {
      "geohash7": "wydm123",
      "count": 6,
      "intensity": 0.72,
      "lat_rounded": 37.5665,
      "lng_rounded": 126.9780
    }
  ]
}
```

## 17.3 뷰모델 변환 규칙
1. `cells` 비어있으면 `empty`.
2. `generated_at` 파싱 실패 시 stale 문구 숨김.
3. `intensity`는 0~1 clamp 후 3단계 버킷으로 매핑.

## 18. 강도 버킷 규칙(핫스팟)
| intensity | 버킷 라벨 | 색상 |
|---|---|---|
| 0.00~0.33 | 낮음 | `appYellowPale` |
| 0.34~0.66 | 보통 | `appYellow` |
| 0.67~1.00 | 높음 | `appGreen` |

## 19. 카피 상세(고정 문구)
## 19.1 상태 문구
- 비공개: `현재 비공개 상태예요`
- 공유중: `익명 공유가 켜져 있어요`
- 권한필요: `위치 권한이 필요해요`

## 19.2 토스트 문구
- 성공 on: `익명 공유가 시작됐어요`
- 성공 off: `익명 공유를 중지했어요`
- 실패: `설정 반영 실패, 다시 시도해주세요`
- 네트워크: `네트워크 연결 후 다시 시도해주세요`

## 20. 예외/경계 상황
## 20.1 연속 탭/중복 요청
- 동일 CTA 1초 내 재탭 무시.
- 진행 중 CTA는 disabled + progress 표시.

## 20.2 백그라운드 전환
- 폴링 중지, foreground 복귀 시 즉시 1회 재조회.

## 20.3 시간 경계(TTL)
- 서버 `last_seen_at` 기준 10분 초과 데이터 제외.
- 클라이언트는 TTL 로직을 재판단하지 않고 서버 결과를 신뢰.

## 20.4 인증 만료
- API 401/403 즉시 recovery banner 노출.
- 라이벌 탭 상단 배지 `인증 필요`.

## 21. 계측 스키마(이벤트 필드)
| 이벤트 | 필수 필드 |
|---|---|
| rival_tab_viewed | `auth_state`, `sharing_state`, `permission_state` |
| rival_privacy_opt_in_completed | `source=consent_sheet`, `latency_ms` |
| rival_hotspot_fetch_succeeded | `cell_count`, `max_intensity`, `latency_ms` |
| rival_hotspot_fetch_failed | `error_code`, `retryable`, `latency_ms` |
| rival_guest_upgrade_clicked | `entry_point=rival_tab` |

## 22. 성능/SLO
1. rival 탭 초기 인터랙션 가능 시점: 1.5초 이내.
2. 핫스팟 재조회 p95: 800ms 이내.
3. 공유 토글 반영 지연: 1초 이내.

## 23. 롤아웃 게이트
## Gate A (내부)
- QA 체크리스트 100% 통과
- 인증/권한/오프라인 회귀 0 blocker

## Gate B (10%)
- 토글 실패율 < 1%
- 핫스팟 조회 실패율 < 3%

## Gate C (50%)
- opt-in 비율/이탈률 이상징후 없음

## Gate D (100%)
- 장애시 `ff_rival_tab_v1` 즉시 off 가능

## 24. 구현 우선순위(개발 태스크 매핑)
1. 상태머신/뷰모델 뼈대
2. PrivacyCard + 동의 시트
3. HotspotCard + polling/cache
4. 게스트/권한/오류 상태
5. 리더보드 skeleton
6. analytics/feature flag wiring

## 25. 최종 DoD
1. 유스케이스 UC-01~UC-09 수동 테스트 통과.
2. CTA-01~05 실패/재시도 경로 검증 완료.
3. 접근성 라벨/동적 폰트 대응 완료.
4. 이벤트 스키마 누락 0건.

## 26. 사용자 여정(End-to-End) 상세
## Journey A: 신규 회원이 라이벌 탭을 처음 켜는 흐름
1. `홈 -> 라이벌 탭` 진입.
2. `비공개` 배지, `익명 공유 시작` CTA 확인.
3. CTA 탭 후 동의 시트 진입.
4. 동의 체크박스 선택 후 `동의하고 시작`.
5. 저장 성공 토스트 확인.
6. 핫스팟 카드 로딩 스켈레톤 -> 결과 렌더.
7. `지도에서 보기` 탭 시 지도 탭으로 이동(핫스팟 레이어 ON 상태).

## Journey B: 산책 중 사용자(지도에서 라이벌 확인)
1. 지도 탭에서 산책 시작.
2. 라이벌 탭 이동.
3. 하단 상태바 `산책 기록 중 · 지도에서 종료 가능` 확인.
4. 라이벌에서 공유 ON/OFF 전환 가능.
5. 지도 탭 복귀 시 산책 세션은 끊기지 않음.
6. 산책 종료는 지도 탭에서만 허용.

## Journey C: 권한 거부 사용자 복구
1. 라이벌 탭 진입 -> `권한 필요` 배지.
2. `설정 열기` 탭으로 iOS 설정 이동.
3. 위치 권한 허용 후 앱 복귀.
4. 포그라운드 복귀 훅에서 권한 재평가.
5. 동의 상태가 ON이면 핫스팟 자동 새로고침.

## 27. 화면/상태 조합 매트릭스
| Auth | Sharing | Permission | Network | 결과 화면 | 노출 CTA |
|---|---|---|---|---|---|
| guest | off | any | any | Guest Locked | 로그인하고 라이벌 시작 |
| member | off | denied | any | Permission Required | 설정 열기 |
| member | off | authorized | online/offline | Consent Required | 익명 공유 시작 |
| member | on | authorized | online | Hotspot Ready | 새로고침, 지도에서 보기, 공유 중지 |
| member | on | authorized | offline + cache | Offline Cached | 다시 시도, 공유 중지 |
| member | on | authorized | offline + no cache | Offline Empty | 다시 시도, 공유 중지 |
| member | on | authorized | online + 5xx | Error Retryable | 다시 시도, 공유 중지 |

## 28. 버튼/토글별 시스템 계약
## BT-01 공유 ON 토글
1. 즉시 UI optimistic update 금지(동의 완료 전).
2. 서버 저장 성공 후에만 상태를 ON으로 표시.
3. 실패 시 상태 유지 + 토스트.

## BT-02 공유 OFF 토글
1. UI 즉시 OFF 반영(낙관적 업데이트 허용).
2. 서버 저장 실패 시 롤백 ON + 토스트.
3. 송신 큐는 OFF 시 즉시 flush 중단.

## BT-03 지도에서 보기
1. 탭 전환: `라이벌 -> 지도`.
2. 지도 오버레이 초기 상태를 `hotspot_enabled=true`로 전달.
3. 지도에서 산책 중이 아니면 오버레이만 표시.

## BT-04 전체 보기(리더보드)
1. `ff_rival_leaderboard_v1=false`이면 준비중 시트 노출.
2. true면 리더보드 상세 화면 push.
3. 상세 화면 실패 시 이전 화면으로 복귀 + 토스트.

## 29. API/캐시/폴링 계약
## 29.1 폴링 타이밍
1. 탭 진입 직후 즉시 1회.
2. 이후 10초 간격.
3. 사용자가 `새로고침` 탭하면 즉시 1회(기존 주기 리셋).

## 29.2 캐시 정책
1. 성공 응답 시 캐시 저장.
2. 캐시 TTL은 10분(UX표시용 stale 판단).
3. 네트워크 에러 시 캐시 우선 렌더 후 에러 배너 동시 노출.

## 29.3 재시도 정책
1. 자동 재시도: 없음(불필요한 트래픽 방지).
2. 수동 재시도: 사용자 CTA 기반.
3. 429 발생 시 30초 재시도 쿨다운 표시.

## 30. 분석/모니터링 KPI 상세
| 카테고리 | 지표 | 목표 |
|---|---|---|
| 전환 | `rival_tab_viewed -> rival_privacy_opt_in_completed` | 25%+ |
| 안정성 | hotspot fetch success rate | 97%+ |
| 품질 | 토글 반영 성공률 | 99%+ |
| 경험 | 탭 진입 후 첫 데이터 렌더 p95 | 1.2s 이하 |
| 보안 | 비동의 사용자 송신률 | 0% |

## 31. 릴리즈 단계별 체크
## Phase 1 (Skeleton + Consent + Hotspot)
1. UC-01~07 완료.
2. 리더보드는 준비중 카드만 제공.
3. 익명 정책 카피/동의 강제.

## Phase 2 (Leaderboard + Report/Block)
1. UC-08, UC-09 활성화.
2. 신고/차단 로컬 반영 + 서버 비동기.
3. 운영자 moderation 로그 연계.

## Phase 3 (확장)
1. 시즌/퀘스트와 라이벌 성과 연결.
2. 친구 관계 기반 비교는 opt-in 추가 동의 필요.
3. 프라이버시 영향 평가 재실시 후 출시.

## 32. 구현 체크리스트(개발용)
1. `RivalTabViewModel` 상태 enum 단일화.
2. `RivalPrivacyUseCase` 분리(동의/토글 저장).
3. `NearbyHotspotUseCase` 분리(조회/캐시/폴링).
4. Feature flag 게이트 분기 테스트 추가.
5. Analytics 이벤트 파라미터 스키마 고정.
6. Deep link(`설정`, `지도`) 라우팅 테스트 추가.

## 33. 비기능 요구사항
1. 앱 재시작 후 마지막 상태 복원 100%.
2. 배터리 영향: 라이벌 탭 백그라운드 폴링 0%.
3. 개인정보 원칙:
   - 개인 식별 가능한 필드 저장/표시 금지.
   - 세션 로그에서 좌표 정밀도 제한(rounded 값만 사용).
4. 장애 시 graceful degradation:
   - 탭 진입 자체는 항상 가능.
   - 데이터만 부분 비활성.
