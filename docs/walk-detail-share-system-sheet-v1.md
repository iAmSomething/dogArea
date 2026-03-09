# Walk Detail Share System Sheet v1

## 목적
- 산책 상세의 `공유하기`가 빈 모달이 아니라 실제 iOS 시스템 공유 시트로 열리게 고정한다.

## 범위
- `WalkListDetailView`
- `WalkDetailView`
- `ViewUtility.ActivityShareSheet`

## 규칙
- SwiftUI `.sheet` 안에 `UIActivityViewController`를 콘텐츠로 넣지 않는다.
- 공유는 현재 호스트 `UIViewController` 위에 직접 `present`한다.
- 이미지 준비 실패 시에도 텍스트 요약만으로 공유를 계속한다.
- 결과는 아래 세 상태로 구분한다.
  - 완료
  - 취소
  - 실패

## 실패 처리
- 빈 호스트/빈 모달 증상은 허용하지 않는다.
- 호스트 미연결, 중복 모달, 빈 아이템이면 실패 피드백으로 종료한다.
- 사용자 메시지는 기술 용어 없이 정리한다.

## 회귀 포인트
- 산책 상세 공유 CTA 탭 후 시스템 share presenter 활성 마커 노출
- 텍스트-only fallback 유지
- 기존 `사진으로 저장하기` 흐름 비영향
