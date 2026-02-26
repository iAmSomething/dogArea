# GitHub Actions Firebase Distribution Runbook (Issue #36)

## 1. 목표
- `main` 머지 또는 수동 실행(`workflow_dispatch`) 시
  - iOS archive/export(IPA)
  - Firebase App Distribution `tester` 그룹 배포
  를 자동 수행한다.

워크플로우 파일:
- `.github/workflows/firebase-distribution.yml`

## 2. 트리거
- 자동: `push` to `main`
- 수동: `workflow_dispatch` (옵션 `release_notes`)

## 3. 시크릿/변수
필수 GitHub Secrets:
- `IOS_DIST_CERT_P12_BASE64`
- `IOS_DIST_CERT_PASSWORD`
- `IOS_PROVISIONING_PROFILE_BASE64`
- `FIREBASE_SERVICE_ACCOUNT_JSON_BASE64` 또는 `FIREBASE_SERVICE_ACCOUNT_JSON`

선택 GitHub Secret:
- `WATCH_PROVISIONING_PROFILE_BASE64`
  - watch 서명 실패 시 설정 권장

선택 GitHub Variables:
- `FIREBASE_APP_ID` (없으면 기본값 사용)
- `FIREBASE_TESTER_GROUP` (없으면 `tester`)

## 4. Apple signing material 준비
1. 배포 인증서(.p12) 생성 후 Base64 인코딩
```bash
base64 -i dist-cert.p12 | pbcopy
```
2. iOS provisioning profile(.mobileprovision) Base64 인코딩
```bash
base64 -i ios.mobileprovision | pbcopy
```
3. watch profile이 있으면 동일 방식으로 `WATCH_PROVISIONING_PROFILE_BASE64` 등록

## 5. Firebase service account 준비
1. Firebase 프로젝트 서비스 계정 JSON 발급
2. 아래 둘 중 하나로 등록
  - Base64 인코딩 후 `FIREBASE_SERVICE_ACCOUNT_JSON_BASE64`
  - 원문 JSON 그대로 `FIREBASE_SERVICE_ACCOUNT_JSON`
```bash
base64 -i firebase-service-account.json | pbcopy
```

## 6. watch profile 분기
- watch profile secret이 비어 있어도 워크플로우는 실행됨
- archive 로그에 watch 서명 오류가 감지되면
  - Step Summary에 `watch 서명 실패 가능성`으로 분류됨
  - `WATCH_PROVISIONING_PROFILE_BASE64` 설정 후 재실행

## 7. 실패 분류 기준
워크플로우 마지막 `Failure classification guide` 단계에서 분류:
- 시크릿 누락: `서명/권한 시크릿 누락`
- archive/export 실패: `빌드/서명 단계 실패`
- Firebase 배포 실패: `Firebase 권한/배포 실패`

## 8. 리허설 실행
수동 실행 1회:
1. GitHub Actions -> `Firebase Distribution`
2. `Run workflow` 클릭
3. `main` 기준 실행
4. 결과 확인
- artifact: `dogArea-ipa-*`
- Firebase 배포 대상 그룹: `tester`

CLI 실행 예시:
```bash
gh workflow run firebase-distribution.yml --ref main
```

## 9. 운영 체크리스트
- [ ] 시크릿 4종 등록 완료
- [ ] (선택) watch profile 시크릿 등록
- [ ] workflow_dispatch 1회 실행
- [ ] artifact 생성 확인
- [ ] tester 그룹 배포 확인
