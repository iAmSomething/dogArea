# 프라이버시 제어 server-first canonical status v1

- Issue: #722
- Related: #727

## 목적

프라이버시 센터의 공유 상태/최근 상태 카드는 기기 로컬 optimistic 상태와 서버 canonical 상태를 섞어 보여주지 않는다.

## 원칙

1. 현재 상태 카드는 **server-first**다.
2. 최근 상태 카드는 마지막 요청의 **server confirmed / local pending / server failed**를 구분한다.
3. `PrivacyControlStateStore`의 로컬 recent status는 **즉시성 fallback**으로만 사용한다.
4. 서버 확인 기록이 없을 때만 `기기 기준` 문구를 쓴다.

## canonical snapshot

`PrivacyControlServerSyncSnapshot`

- `desiredEnabled`
- `canonicalEnabled`
- `requestedAt`
- `resultRecordedAt`
- `serverUpdatedAt`
- `requestId`
- `state`
  - `localPending`
  - `serverConfirmed`
  - `serverFailed`
- `failureCategory`
  - `offline`
  - `serverDelayed`
  - `authRequired`
  - `unknown`
- `failureCode`

## 우선순위

### 1. current status

- `serverConfirmed`가 있으면 서버 기준 상태를 그대로 보여준다.
- `localPending`이면 `서버 확인 대기`를 보여주고, 마지막으로 확인된 canonical 상태를 함께 적는다.
- `serverFailed`이면 실패 분류와 마지막 canonical 상태를 함께 적는다.
- snapshot이 없을 때만 `이 기기에 저장된 기본값` 문구로 fallback 한다.

### 2. recent status

- `serverConfirmed`: 마지막 요청이 서버에 반영됐는지, 현재 서버 기준이 무엇인지 보여준다.
- `localPending`: 마지막 요청 시각 + 현재 확인된 canonical 상태 + `서버 확인 대기`를 보여준다.
- `serverFailed`: 마지막 요청 시각 + 실패 분류/코드 + 마지막 canonical 상태를 보여준다.
- snapshot이 없을 때만 `PrivacyControlRecentStatus`를 읽는다.

## 실패 분류

- `offline`: 기기 요청은 저장했지만 서버 확인이 보류됨
- `serverDelayed`: 서버 응답/반영 확인이 지연됨
- `authRequired`: 서버 인증 상태를 다시 확인해야 함
- `unknown`: 위 세 범주로 좁히지 못한 실패

## 카피 규칙

- `ON/OFF/TODO/CHECK/TEMP/QUIET` 같은 내부 vocabulary를 사용자 표면에 쓰지 않는다.
- 서버 확인 완료: `서버 반영 완료`
- 서버 확인 전: `서버 확인 대기`
- 오프라인 실패: `오프라인 보류`
- 인증 확인 필요: `확인 필요`
- 서버 지연: `서버 지연`

## 기록 경로

- 설정 탭 프라이버시 센터 토글
- 지도에서 공유 상태 동기화
- 라이벌 탭 공유 동의/철회

위 3개 경로가 모두 같은 snapshot 저장 규칙을 사용해야 한다.
