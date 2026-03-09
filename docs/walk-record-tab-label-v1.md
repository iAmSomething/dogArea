# Walk Record Tab Label v1

## 목적
- 전역 탭바의 사용자 노출 명칭을 `산책 목록`이 아니라 `산책 기록`으로 통일합니다.
- 이미 화면 헤더와 상세 프레젠테이션에서 사용 중인 표현과 맞춰 제품 표면 용어를 일관화합니다.

## 적용 범위
- 하단 탭바의 `tab.1` 라벨/접근성 라벨
- 지도 설정 시트의 기록 섹션 제목
- 현재 유지 중인 제품 문서/회귀 체크의 사용자 표면 표현

## 비범위
- 내부 타입명 `WalkList*`
- 파일명/디렉터리명
- 라우팅 순서나 탭 구조

## 규칙
1. 사용자에게 보이는 탭 이름은 `산책 기록`으로 고정합니다.
2. 기록 화면을 가리키는 보조 표면도 가능하면 `산책 기록`으로 맞춥니다.
3. 내부 구현 식별자(`WalkList`, `tab.1`)는 유지합니다.

## 회귀 방지
- 정적 체크: `swift scripts/walk_record_tab_label_unit_check.swift`
- UI 회귀: `FeatureRegressionUITests/testFeatureRegression_WalkListTabSelectedIconRemainsVisibleInBothStyles`
