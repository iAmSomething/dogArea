# Weather Snapshot Provider v1

## 1. 목표
- 홈/맵/실내 미션이 같은 날씨 스냅샷 계약을 공유하도록 표준화한다.
- 위험도 계산에만 쓰이던 weather provider를 상세 수치 기반 계약으로 확장한다.

## 2. 공통 Snapshot 필드
- `level`
- `observedAt`
- `location.latitude`
- `location.longitude`
- `temperatureC`
- `apparentTemperatureC`
- `relativeHumidityPercent`
- `isPrecipitating`
- `precipitationMMPerHour`
- `windMps`
- `pm2_5`
- `pm10`
- `weatherSource`
- `airQualitySource`

## 3. Provider 정책
- primary weather: `https://api.open-meteo.com/v1/forecast`
  - current: `temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,wind_speed_10m`
- optional air quality: `https://air-quality-api.open-meteo.com/v1/air-quality`
  - current: `pm10,pm2_5`
- weather endpoint는 위험도 계산의 canonical source다.
- air quality endpoint는 상세 카드 확장용 보조 source다.

## 4. Null / Fallback 정책
- `temperatureC`, `apparentTemperatureC`, `relativeHumidityPercent`, `precipitationMMPerHour`, `windMps`는 core weather 필드다.
- core weather 필드가 누락되면 provider 요청은 실패로 간주한다.
- `pm2_5`, `pm10`은 optional 필드다.
- 공기질 endpoint가 실패하거나 값을 주지 않으면 `pm2_5`, `pm10`은 `nil`로 저장하고 `airQualitySource = unavailable`로 기록한다.
- provider 자체가 실패하면 소비자는 마지막 정상 snapshot을 사용한다.
- 마지막 snapshot이 `2h`를 초과하면 `clear`로 강등하지 않고 최소 `caution`으로 보수 판정한다.

## 5. 상태 전달 구조
- Map provider fetch -> `WeatherSnapshotStore` 저장
- Home -> `WeatherSnapshotStore` 조회
- Indoor mission -> `WeatherSnapshotStore` 조회 후 risk 계산
- legacy `weather.risk.level.v1` / `weather.risk.observed_at.v1`는 호환을 위해 함께 유지한다.

## 6. 위치 / 관측 기준
- `observedAt`은 provider `current.time` 기준 UTC epoch로 저장한다.
- `location`은 snapshot을 요청한 기준 좌표다.
- 홈은 이후 `최근 산책 기록` 기준 좌표를 사용해 snapshot을 refresh할 수 있다.
