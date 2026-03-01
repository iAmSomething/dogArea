# Rival Tab UI Design Spec v1.1

## 1. 디자인 목표
- 앱 전체 톤(파스텔 옐로우/화이트 카드/둥근 모서리/라이트 타이포)을 유지한다.
- "경쟁" 기능이지만 공격적/자극적 톤보다 "안전한 익명 비교" 톤을 우선한다.
- 홈/지도와 시각적으로 같은 제품으로 보이되, 라이벌 탭만의 정보 우선순위를 분명히 한다.

## 2. 현재 앱 스타일 기준(정합성 기준선)
## 2.1 Color Token (코드 기준)
- `Color.appYellow` : 주요 CTA/강조
- `Color.appYellowPale` : 안내 배경, 보조 카드
- `Color.appGreen` : 성공/활성 상태
- `Color.appRed` : 경고/실패
- `Color.appTextDarkGray` : 보조 텍스트
- `Color.appTextLightGray` : 경계/비활성
- `Color.appPinkYello` : 강조 카드 배경

## 2.2 Typography (코드 기준)
- 대제목: `.appFont(.SemiBold, 40)`
- 섹션 타이틀: `.appFont(.SemiBold, 20)`
- 본문: `.appFont(.Regular, 13)`
- 보조/라벨: `.appFont(.Light, 11~12)`

## 2.3 모서리/카드
- 카드 모서리: 10~12
- 버튼 모서리: 8~10
- 구분선: `Color.appTextDarkGray` 0.2~0.4

## 3. 라이벌 탭 비주얼 컨셉
### 컨셉 키워드
- `익명`, `안전`, `근처 열기`, `부담 없는 경쟁`

### 톤 가이드
- 배경: `appYellowPale` 계열의 연한 톤
- 주 카드: 흰색 배경 + 얇은 테두리
- 상태 배지:
  - 공유중: `appGreen`
  - 비공개: `appTextLightGray`
  - 에러/권한필요: `appRed`

## 4. 레이아웃 시스템
## 4.1 공통 여백
- 좌우 기본 패딩: 16
- 카드 내부 패딩: 10~12
- 섹션 간 간격: 12
- 카드 간 간격: 8

## 4.2 세로 흐름
1. Title/Header
2. 상태 배지 라인
3. 프라이버시 동의 카드
4. 익명 핫스팟 카드
5. 리더보드 요약 카드
6. 라이벌 진입 카드

## 5. 화면 설계(동작 단위)
## Screen A: Rival Home (기본)
### Header
- 타이틀: `라이벌`
- 서브타이틀: `근처 산책 열기를 익명으로 확인해요`
- 스타일:
  - 타이틀: `.SemiBold 40`
  - 서브타이틀: `.Light 15`, `appTextDarkGray`

### Status Pill Row
- 좌측: 공유 상태 배지
  - `비공개` / `공유 중`
- 우측: 권한 상태 배지
  - `위치 허용` / `권한 필요`

### Card 1: Privacy Control
- 제목: `익명 위치 공유`
- 설명:
  - `닉네임/강아지명/정밀 좌표는 노출되지 않아요`
- 버튼:
  - 상태 off: `익명 공유 시작` (`appYellow`)
  - 상태 on: `공유 중지` (`appTextLightGray`)

### Card 2: Nearby Hotspot
- 제목: `근처 익명 핫스팟`
- 본문:
  - `활성 핫스팟 n개`
  - `마지막 업데이트 HH:mm`
- CTA:
  - `새로고침`
  - `지도에서 보기`

### Card 3: Rival Summary
- 제목: `주간 라이벌 요약`
- 상태:
  - Phase1: skeleton + `준비 중`
  - Phase2: `내 티어`, `기여 횟수`, `이번 주 추이`
- CTA: `전체 보기`

## Screen B: Privacy Consent Sheet
- Detent: `.medium`
- 구성:
  1. 헤더 아이콘(쉴드)
  2. 동의 설명 3줄
  3. 체크박스 1개
  4. 하단 버튼 2개(취소/동의하고 시작)
- 버튼 규칙:
  - 체크 전 `동의하고 시작` 비활성

## Screen C: Permission Required State
- Card only 화면
- 문구:
  - `근처 핫스팟을 보려면 위치 권한이 필요해요`
- 버튼:
  - `설정 열기`
  - `나중에`

## Screen D: Offline/Error State
- Empty card + 아이콘
- 문구:
  - 오프라인: `네트워크 복구 후 자동으로 갱신돼요`
  - 서버오류: `잠시 후 다시 시도해주세요`
- 액션:
  - `다시 시도`

## 6. 컴포넌트 디자인 상세
## 6.1 Badge
- 높이 24, 좌우 8
- 폰트 `.SemiBold 11`
- 배경:
  - success: `appGreen.opacity(0.35)`
  - neutral: `appTextLightGray.opacity(0.35)`
  - danger: `appRed.opacity(0.2)`

## 6.2 Card
- 배경: white
- cornerRadius: 10
- border: `appTextDarkGray`, 0.25
- 그림자: 기본 없음(홈과 동일 톤 유지)

## 6.3 Button
- Primary:
  - bg `appYellow`
  - text black
  - corner 8
- Secondary:
  - bg `appYellowPale`
  - text `appTextDarkGray`
- Destructive-lite:
  - bg `appTextLightGray`
  - text `appTextDarkGray`

## 6.4 Skeleton
- `appTextLightGray.opacity(0.3)` 라운드 블록
- shimmer는 Phase2에서만 검토(현재 스타일상 과도한 모션 금지)

## 7. 모션/피드백
1. 카드 상태 전환: `easeInOut 0.2`
2. 토글 성공: 경량 햅틱 1회
3. 실패 토스트: 상단 슬라이드 + 2.5초 자동 닫힘
4. 저전력/Reduce Motion일 때:
   - 모션 최소화(페이드만)

## 8. 접근성
1. Badge/상태는 색+텍스트 동시 제공.
2. VoiceOver 라벨:
   - `익명 공유 상태 비공개`
   - `위치 권한 필요`
3. 버튼 최소 터치 44pt.
4. Dynamic Type 대응:
   - 타이틀 제외 모든 라벨 2줄 허용.

## 9. 탭바 정합성 규칙
- 5탭 확장 시에도 현재 커스텀 탭바 스타일 유지:
  - 아이콘 상단, 텍스트 하단(`TabStyle`)
  - 지도 탭만 중앙 강조 허용
- 라이벌 탭 아이콘 후보:
  1. `person.2.fill`
  2. `flag.2.crossed.fill`
  3. `bolt.heart.fill` (채택 비권장: 의미 불명확)

권장: `person.2.fill` + 라벨 `라이벌`

## 10. 반응형 규칙
## iPhone SE/mini
- 헤더 타이틀 40 -> 32 자동 축소
- 카드 간격 12 -> 8

## iPhone Pro Max
- 기본 값 유지
- 카드 max width 제한 없이 full bleed + 16 패딩

## 11. 구현 우선순위
1. 토큰/레이아웃 고정
2. Rival Home 기본 카드 2종(Privacy, Hotspot)
3. 상태별(권한/오프라인/에러) UI
4. 리더보드 요약 카드(스켈레톤)

## 12. 디자이너/개발 핸드오프 체크리스트
1. 색상값이 기존 `Color.swift` 토큰만 사용하는지 확인
2. 폰트가 `appFont` 규격을 벗어나지 않는지 확인
3. 카드 코너/테두리 굵기 일관성 확인
4. 상태별 문구/버튼 레이블 고정 확인
5. 접근성 라벨 점검

## 13. 스크린 미리보기 텍스트 와이어
```text
[라이벌]
근처 산책 열기를 익명으로 확인해요
[비공개] [권한 필요]

┌ 익명 위치 공유 ───────────────────┐
  닉네임/강아지명/정밀 좌표는 노출되지 않아요
  [익명 공유 시작]
└────────────────────────────────────┘

┌ 근처 익명 핫스팟 ─────────────────┐
  동의 후 이용할 수 있어요
  [설정 보기]
└────────────────────────────────────┘

┌ 주간 라이벌 요약 ─────────────────┐
  준비 중
  [전체 보기]
└────────────────────────────────────┘
```

## 14. 컴포넌트 단위 스펙(픽셀/행동)
## 14.1 Header Block
- 높이: 컨텐츠 기반(최소 92)
- 상단 패딩: safe area + 8
- 좌우 패딩: 16
- 타이틀과 서브타이틀 간격: 4
- 상태 배지 행 간격: 8

## 14.2 Privacy Card
- 최소 높이: 118
- 내부 레이아웃:
  - 제목(20) -> 설명(13) -> CTA 버튼(44) 순
  - 각 간격: 6 / 10
- 토글 동작:
  - 로딩 중 버튼 우측에 `ProgressView` inline
  - 로딩 중 재탭 금지

## 14.3 Hotspot Card
- 최소 높이: 132
- 상태별 하위 뷰:
  - loading: skeleton 2줄 + 버튼 2개 skeleton
  - ready: 통계 텍스트 + CTA 버튼 2개
  - empty: 일러스트 아이콘 + 안내 문구 + 새로고침
  - error/offline: 경고 아이콘 + 재시도 버튼

## 14.4 Leaderboard Card
- 최소 높이: 112
- Phase1:
  - 타이틀 + `준비 중` 배지 + `전체 보기` 비활성
- Phase2:
  - 티어 뱃지, 기여횟수 칩, 변화량 화살표

## 15. 네비게이션/전환 디자인
## 15.1 탭 전환
1. 라이벌 -> 지도:
   - 기본 탭 전환 애니메이션 유지.
   - 추가 커스텀 전환 없음(앱 일관성 우선).
2. 라이벌 -> 설정:
   - deep link 진입 시 설정 화면 상단에 `라이벌 개인정보` 섹션으로 자동 스크롤.

## 15.2 시트/다이얼로그
1. 동의 시트:
   - 배경 dimmed 30%.
   - 닫기 제스처 허용.
2. 공유 중지:
   - 확인 다이얼로그 미사용.
   - 토스트로 피드백 제공.

## 16. 상태별 시각 규칙
| 상태 | 카드 배경 | 배지 | CTA 톤 |
|---|---|---|---|
| 비공개 | white | neutral | primary(`익명 공유 시작`) |
| 공유중 | white | success | secondary(`공유 중지`) |
| 권한 필요 | white | danger | secondary(`설정 열기`) |
| 오프라인 | white | neutral | secondary(`다시 시도`) |
| 에러 | white | danger | secondary(`다시 시도`) |

## 17. 미세 상호작용(Micro Interaction)
1. 공유 시작 성공:
   - 버튼 라벨이 `익명 공유 시작` -> `공유 중지`로 crossfade(0.2s).
2. 핫스팟 새로고침:
   - 카드 오른쪽 상단의 시각 시계 아이콘 회전(0.4s, 1회).
3. 에러 토스트:
   - 상단에서 내려와 2.5초 후 자동 사라짐.
4. 접근성 Reduce Motion:
   - 회전/슬라이드 제거, opacity 전환만 사용.

## 18. 카피/아이콘 가이드
## 18.1 아이콘 매핑
- 라이벌 탭: `person.2.fill`
- 프라이버시 카드: `lock.shield.fill`
- 핫스팟 카드: `location.viewfinder`
- 오프라인: `wifi.slash`
- 에러: `exclamationmark.triangle.fill`

## 18.2 금지 카피
1. `실시간 위치`, `개별 사용자 위치` 표현 금지.
2. `추적`, `감시` 등 위협 뉘앙스 단어 금지.
3. `무조건`, `완벽` 같은 과장 표현 금지.

## 19. 반응형/디바이스별 세부
## 19.1 Compact Height (SE/mini)
1. 헤더 타이틀 32pt.
2. 카드 최소 높이 -8.
3. 상태 배지 1줄 고정, 넘치면 스크롤이 아니라 줄바꿈 허용.

## 19.2 Regular Width (iPad 미지원 대비)
1. 현재 iPhone 우선 배치 유지.
2. 향후 iPad 확장 시 카드 max width 560, 중앙 정렬.

## 20. 접근성 상세 규칙
1. `익명 공유 시작` 버튼:
   - VoiceOver: `익명 위치 공유 시작 버튼`.
2. 공유 상태 배지:
   - VoiceOver: `공유 상태, 비공개` 또는 `공유 상태, 공유 중`.
3. 핫스팟 강도:
   - 색상만이 아니라 텍스트로 `낮음/보통/높음` 반드시 표기.
4. Dynamic Type:
   - `Large` 이상에서 카드 버튼 2줄까지 허용.

## 21. 구현 매핑(SwiftUI)
1. `RivalTabView`
   - 상단: `RivalHeaderView`
   - 본문: `RivalPrivacyCard`, `NearbyHotspotCard`, `RivalLeaderboardCard`
2. 공통 스타일:
   - 기존 `TabStyle`, `appFont`, `Color` 토큰 재사용.
3. 상태 바인딩:
   - 단일 state enum -> 각 카드 서브뷰에 파생 값 전달.

## 22. QA용 시각 검증 포인트
1. 홈/지도와 카드 radius/테두리 두께 차이 없음.
2. 앱 전체에서 yellow 톤 편차 없음.
3. 라이벌 탭만 과한 모션/강한 채도 사용 금지.
4. 오류/오프라인에서 버튼이 사라지지 않고 항상 복구 경로 제공.
