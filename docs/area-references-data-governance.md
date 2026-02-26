# Area References Data Governance v1

## 1. 목적
명소/지자체 넓이 비교군(`area_references`) 데이터를 신뢰 가능한 기준으로 확장/운영하기 위한 문서다.
본 문서는 구현 이슈 #22에서 seed 확장 작업의 기준 문서로 사용한다.

연결 이슈:
- 문서: #40
- 구현: #22

## 2. 범위
- 데이터 소스 선정 기준
- 갱신 주기/검증 방식
- `area_references` 컬럼 운영 규칙
- seed 배치 전략
- 운영 검증 쿼리

## 3. 테이블 운영 규칙
대상 테이블: `public.area_references`

핵심 컬럼 규칙:
- `reference_name`: 고유 이름(중복 금지)
- `area_m2`: m² 기준 실수값, 0 초과
- `category`: 아래 enum-like 정책 준수
  - `legacy`
  - `administrative`
  - `park`
  - `landmark`
  - `island`
  - `custom`
- `country_code`: ISO 3166-1 alpha-2 (예: `KR`, `US`)
- `source_label`: 출처 기관/문서명
- `source_url`: 원문 링크
- `source_note`: 면적 단위 환산 방식/주의점
- `is_active`: 앱 노출 여부
- `metadata`: 확장 필드(JSON)

metadata 권장 키:
- `unit_original` (예: `km2`)
- `converted_at` (ISO8601)
- `version`
- `region_type` (city, district, park, etc.)

## 4. 소스 선정 정책

### 4.1 허용 소스 우선순위
1. 정부/공공기관 공식 통계 (최우선)
2. 도시/공원 관리기관 공식 문서
3. 국제기구/공신력 있는 데이터 포털
4. 위키/커뮤니티 데이터 (보조만, 단독 금지)

### 4.2 제외 기준
- 출처 불명
- 업데이트 날짜 미확인
- 단위/범위 정의 불명확(행정구역 경계 변경 반영 여부 등)

### 4.3 단위 표준
- 저장은 항상 `m²`
- 소스 단위가 `km²`인 경우 `m² = km² * 1_000_000`
- 소수점 처리: 원본 정밀도 유지(반올림 최소화)

## 5. 갱신 주기
- `administrative`: 반기(6개월) 점검
- `park/landmark/island`: 연 1회 점검
- 변경 이벤트(행정구역 개편/공식 공지) 발생 시 즉시 업데이트

운영 규칙:
- 기존 행 수정보다 “변경 로그가 필요한 경우” 새 버전 행 생성 + 이전 행 비활성
- 단순 오탈자/URL 보정은 기존 행 update 허용

## 6. Seed 배치 전략

### 6.1 배치 원칙
- seed SQL은 idempotent 해야 함 (`ON CONFLICT ... DO UPDATE` 권장)
- 대량 삽입 시 카테고리 단위로 파일 분리 가능
- PR 단위로 “추가/수정/비활성” 변경 목록을 명시

### 6.2 배치 순서
1. `legacy` 데이터 반영/정합화
2. `administrative` 공식 데이터 반영
3. `park/landmark/island` 확장
4. 품질 검증 쿼리 실행

## 7. 소스 카탈로그 (초안)

| category | source_label | source_url | notes |
|---|---|---|---|
| administrative (KR) | KOSIS 국가통계포털 | https://kosis.kr | 행정구역 면적 기준 |
| administrative (KR) | 국가지표체계/e-나라지표 | https://www.index.go.kr | 보조 검증용 |
| park (US) | NYC Parks | https://www.nycgovparks.org | 센트럴파크 등 |
| park (US) | LA City / Griffith Park | https://www.laparks.org | 그리피스 파크 |
| park (US) | Golden Gate National Parks Conservancy | https://www.parksconservancy.org | 골든게이트 공원권역 |
| island (global) | 정부/공식 관광청 페이지 | varies | 섬 면적은 공식 통계 우선 |

주의:
- 위 표는 관리 기준 카탈로그이며, 실제 삽입 시점에 URL/값 최신성 재검증 필수.

## 8. 품질 검증 체크리스트

### 8.1 사전 검증
- [ ] source_url 접속 가능
- [ ] source_label/source_note 기입
- [ ] 원본 단위와 환산식 기록

### 8.2 정합성 검증
- [ ] `reference_name` 중복 없음
- [ ] `area_m2 > 0`
- [ ] `category` 정책값 준수
- [ ] `country_code` 형식 준수

### 8.3 배포 후 검증
- [ ] 앱 비교 카드 조회 정상
- [ ] 가까운 면적 비교 로직에서 역전/정렬 오류 없음
- [ ] 비활성(`is_active=false`) 데이터가 사용자 노출에서 제외됨

## 9. 운영 검증 SQL
```sql
-- 1) 중복 이름 확인
select reference_name, count(*)
from public.area_references
group by reference_name
having count(*) > 1;

-- 2) 비정상 면적 확인
select id, reference_name, area_m2
from public.area_references
where area_m2 <= 0;

-- 3) source 메타 누락 확인
select id, reference_name
from public.area_references
where source_label is null
   or source_url is null;

-- 4) 카테고리 정책 위반 확인
select id, reference_name, category
from public.area_references
where category not in ('legacy', 'administrative', 'park', 'landmark', 'island', 'custom');

-- 5) 활성 데이터 개수/범위 점검
select category, count(*)
from public.area_references
where is_active = true
group by category
order by category;
```

## 10. 변경 관리 프로세스
1. 데이터 후보 수집
2. 소스 검증(최소 1개 공식 소스)
3. 변환/정규화 스크립트 또는 SQL 작성
4. 검증 SQL 통과
5. PR 설명에 추가 목록/근거 링크 첨부
6. 머지 후 앱 비교 화면 스모크 테스트

## 11. 롤백 기준
- 잘못된 값 배포 시 즉시 `is_active=false`로 노출 차단
- 원인 분석 후 수정 seed 배포
- 데이터 삭제는 마지막 수단(이력 추적 필요)

## 12. 비범위
- 사용자 커스텀 비교군 직접 등록 기능
- 국가별 자동 크롤링 파이프라인 구축
- 실시간 외부 API 동기화
