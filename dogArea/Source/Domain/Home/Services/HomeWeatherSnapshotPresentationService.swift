import Foundation

/// 홈 날씨 상세 카드의 사용자 노출 프레젠테이션을 생성하는 계약입니다.
protocol HomeWeatherSnapshotPresenting {
    /// 날씨 스냅샷과 미션 상태를 바탕으로 홈 상세 카드 프레젠테이션을 생성합니다.
    /// - Parameters:
    ///   - snapshot: 공용 저장소에 저장된 최신 날씨 스냅샷입니다.
    ///   - missionSummary: 날씨가 오늘 미션에 미치는 영향을 요약한 정보입니다.
    ///   - now: 현재 시각입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 홈 상세 카드가 바로 렌더링할 수 있는 프레젠테이션 모델입니다.
    func makePresentation(
        snapshot: WeatherSnapshot?,
        missionSummary: WeatherMissionStatusSummary,
        now: Date,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> HomeWeatherSnapshotCardPresentation
}

final class HomeWeatherSnapshotPresentationService: HomeWeatherSnapshotPresenting {
    private enum Constants {
        static let staleThreshold: TimeInterval = 20 * 60
    }

    private static let observedTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    /// 날씨 스냅샷과 미션 상태를 바탕으로 홈 상세 카드 프레젠테이션을 생성합니다.
    /// - Parameters:
    ///   - snapshot: 공용 저장소에 저장된 최신 날씨 스냅샷입니다.
    ///   - missionSummary: 날씨가 오늘 미션에 미치는 영향을 요약한 정보입니다.
    ///   - now: 현재 시각입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 홈 상세 카드가 바로 렌더링할 수 있는 프레젠테이션 모델입니다.
    func makePresentation(
        snapshot: WeatherSnapshot?,
        missionSummary: WeatherMissionStatusSummary,
        now: Date,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> HomeWeatherSnapshotCardPresentation {
        guard let snapshot else {
            return placeholderPresentation(
                missionSummary: missionSummary,
                localizedCopy: localizedCopy
            )
        }

        let metrics = makeMetrics(snapshot: snapshot, localizedCopy: localizedCopy)
        let observedAtText = makeObservedAtText(
            observedAt: snapshot.observedAt,
            now: now,
            localizedCopy: localizedCopy
        )
        let sourceLineText = makeSourceLineText(
            snapshot: snapshot,
            now: now,
            localizedCopy: localizedCopy
        )
        let missionHintText = makeMissionHintText(
            riskLevel: missionSummary.riskLevel,
            localizedCopy: localizedCopy
        )
        let badgeText = makeStatusBadgeText(
            snapshot: snapshot,
            now: now,
            localizedCopy: localizedCopy
        )
        let accessibilityText = (
            [localizedCopy("지금 날씨 상세", "Current Weather Details")]
            + metrics.map(\.accessibilityText)
            + [observedAtText, sourceLineText, missionHintText]
        )
        .joined(separator: ". ")

        return HomeWeatherSnapshotCardPresentation(
            title: localizedCopy("지금 날씨 상세", "Current Weather Details"),
            subtitle: localizedCopy(
                "기온, 체감, 습도, 강수, 공기질을 한 번에 확인하세요.",
                "Review temperature, feels-like, humidity, precipitation, and air quality at a glance."
            ),
            statusBadgeText: badgeText,
            metrics: metrics,
            observedAtText: observedAtText,
            sourceLineText: sourceLineText,
            missionHintText: missionHintText,
            accessibilityText: accessibilityText,
            isPlaceholder: false,
            isFallback: isFallback(snapshot: snapshot, now: now)
        )
    }

    /// 상세 카드에 노출할 날씨 지표 배열을 생성합니다.
    /// - Parameters:
    ///   - snapshot: 렌더링 대상 날씨 스냅샷입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 홈 카드에 표시할 원시 지표 프레젠테이션 목록입니다.
    private func makeMetrics(
        snapshot: WeatherSnapshot,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> [HomeWeatherMetricPresentation] {
        let dustValueAndDetail = makeDustValueAndDetail(snapshot: snapshot, localizedCopy: localizedCopy)
        return [
            makeMetric(
                id: "temperature",
                title: localizedCopy("기온", "Temperature"),
                valueText: makeTemperatureText(snapshot.temperatureC),
                detailText: nil
            ),
            makeMetric(
                id: "feelsLike",
                title: localizedCopy("체감", "Feels Like"),
                valueText: makeTemperatureText(snapshot.apparentTemperatureC),
                detailText: nil
            ),
            makeMetric(
                id: "humidity",
                title: localizedCopy("습도", "Humidity"),
                valueText: "\(Int(snapshot.relativeHumidityPercent.rounded()))%",
                detailText: nil
            ),
            makeMetric(
                id: "precipitationState",
                title: localizedCopy("강수 여부", "Precipitation"),
                valueText: snapshot.isPrecipitating || snapshot.precipitationMMPerHour > 0.1
                    ? localizedCopy("비 내림", "Raining")
                    : localizedCopy("없음", "None"),
                detailText: nil
            ),
            makeMetric(
                id: "precipitationAmount",
                title: localizedCopy("강수량", "Rain Amount"),
                valueText: String(format: localizedCopy("%.1f mm/h", "%.1f mm/h"), snapshot.precipitationMMPerHour),
                detailText: nil
            ),
            makeMetric(
                id: "dust",
                title: localizedCopy("미세먼지", "Air Quality"),
                valueText: dustValueAndDetail.value,
                detailText: dustValueAndDetail.detail
            )
        ]
    }

    /// 개별 지표 프레젠테이션을 생성합니다.
    /// - Parameters:
    ///   - id: UI 테스트와 식별에 사용할 고정 키입니다.
    ///   - title: 사용자에게 보일 지표 제목입니다.
    ///   - valueText: 지표의 핵심 값 문자열입니다.
    ///   - detailText: 필요 시 함께 노출할 보조 설명입니다.
    /// - Returns: 카드 그리드 한 칸에 해당하는 지표 프레젠테이션입니다.
    private func makeMetric(
        id: String,
        title: String,
        valueText: String,
        detailText: String?
    ) -> HomeWeatherMetricPresentation {
        let accessibilityText = ([title, valueText] + [detailText].compactMap { $0 }).joined(separator: " ")
        return HomeWeatherMetricPresentation(
            id: id,
            title: title,
            valueText: valueText,
            detailText: detailText,
            accessibilityText: accessibilityText
        )
    }

    /// 날씨 스냅샷이 없을 때 표시할 플레이스홀더 프레젠테이션을 생성합니다.
    /// - Parameters:
    ///   - missionSummary: 날씨가 오늘 미션에 미치는 영향을 요약한 정보입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 데이터가 비어 있어도 레이아웃이 무너지지 않는 기본 카드 프레젠테이션입니다.
    private func placeholderPresentation(
        missionSummary: WeatherMissionStatusSummary,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> HomeWeatherSnapshotCardPresentation {
        HomeWeatherSnapshotCardPresentation(
            title: localizedCopy("지금 날씨 상세", "Current Weather Details"),
            subtitle: localizedCopy(
                "기온, 체감, 습도, 강수, 공기질을 한 번에 확인하세요.",
                "Review temperature, feels-like, humidity, precipitation, and air quality at a glance."
            ),
            statusBadgeText: localizedCopy("준비 중", "Pending"),
            metrics: HomeWeatherSnapshotCardPresentation.placeholder.metrics.map { metric in
                HomeWeatherMetricPresentation(
                    id: metric.id,
                    title: localizedCopy(metric.title, metric.title),
                    valueText: localizedCopy("확인 중", "Loading"),
                    detailText: nil,
                    accessibilityText: localizedCopy("\(metric.title) 확인 중", "\(metric.title) loading")
                )
            },
            observedAtText: localizedCopy("관측 시각 확인 중", "Observation time pending"),
            sourceLineText: localizedCopy(
                "최근 관측값을 준비 중입니다. 산책 기록이 생기면 자동으로 채워져요.",
                "The latest observation is not ready yet. It will fill in automatically after the next walk context update."
            ),
            missionHintText: makeMissionHintText(
                riskLevel: missionSummary.riskLevel,
                localizedCopy: localizedCopy
            ),
            accessibilityText: localizedCopy(
                "지금 날씨 상세. 최근 관측값을 준비 중입니다.",
                "Current weather details are not ready yet."
            ),
            isPlaceholder: true,
            isFallback: true
        )
    }

    /// 섭씨 값을 사용자 노출용 온도 문자열로 변환합니다.
    /// - Parameter temperature: 섭씨 기준 온도 값입니다.
    /// - Returns: 반올림된 온도 문자열입니다.
    private func makeTemperatureText(_ temperature: Double) -> String {
        "\(Int(temperature.rounded()))°"
    }

    /// 미세먼지 표시 문자열과 보조 설명 문자열을 생성합니다.
    /// - Parameters:
    ///   - snapshot: 렌더링 대상 날씨 스냅샷입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 미세먼지 타일의 핵심 값과 보조 설명 문자열입니다.
    private func makeDustValueAndDetail(
        snapshot: WeatherSnapshot,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> (value: String, detail: String?) {
        let pm25Text = snapshot.pm2_5.map { "PM2.5 \(Int($0.rounded()))" }
        let pm10Text = snapshot.pm10.map { "PM10 \(Int($0.rounded()))" }

        switch (pm25Text, pm10Text) {
        case let (pm25?, pm10?):
            return (pm25, pm10)
        case let (pm25?, nil):
            return (pm25, localizedCopy("보조 지표 없음", "No secondary metric"))
        case let (nil, pm10?):
            return (pm10, localizedCopy("보조 지표 없음", "No secondary metric"))
        case (nil, nil):
            return (localizedCopy("준비 중", "Pending"), nil)
        }
    }

    /// 관측 시각 문자열을 생성합니다.
    /// - Parameters:
    ///   - observedAt: 스냅샷 관측 시각(epoch seconds)입니다.
    ///   - now: 현재 시각입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 카드 하단에 노출할 관측 시각 안내 문자열입니다.
    private func makeObservedAtText(
        observedAt: TimeInterval,
        now: Date,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> String {
        let observedDate = Date(timeIntervalSince1970: observedAt)
        let observedText = Self.observedTimeFormatter.string(from: observedDate)
        let age = now.timeIntervalSince1970 - observedAt
        if age > Constants.staleThreshold {
            return localizedCopy(
                "관측 시각 \(observedText) · 최신화 대기",
                "Observed \(observedText) · Awaiting refresh"
            )
        }
        return localizedCopy(
            "관측 시각 \(observedText)",
            "Observed at \(observedText)"
        )
    }

    /// 원시 날씨 카드의 데이터 출처 안내 문구를 생성합니다.
    /// - Parameters:
    ///   - snapshot: 렌더링 대상 날씨 스냅샷입니다.
    ///   - now: 현재 시각입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 카드 하단에 작게 노출할 출처/보정 상태 문자열입니다.
    private func makeSourceLineText(
        snapshot: WeatherSnapshot,
        now: Date,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> String {
        let age = now.timeIntervalSince1970 - snapshot.observedAt
        if snapshot.weatherSource == .fallback || snapshot.airQualitySource == .fallback {
            return localizedCopy(
                "일부 지표는 최근 안전 기준을 이어받아 보여줘요.",
                "Some values are carried forward from the most recent safe baseline."
            )
        }
        if snapshot.airQualitySource == .unavailable {
            return localizedCopy(
                "날씨는 실시간 기준이고 공기질 수치는 아직 준비되지 않았어요.",
                "Weather is live, but the air-quality reading is not ready yet."
            )
        }
        if age > Constants.staleThreshold {
            return localizedCopy(
                "최근 관측값을 유지하고 있어요. 다음 갱신 때 자동으로 최신화됩니다.",
                "The latest cached observation is still shown and will refresh automatically."
            )
        }
        return localizedCopy(
            "실시간 날씨와 공기질 관측값을 함께 반영했어요.",
            "Live weather and air-quality readings are both applied."
        )
    }

    /// 상세 카드 우측 상단 배지 문구를 생성합니다.
    /// - Parameters:
    ///   - snapshot: 렌더링 대상 날씨 스냅샷입니다.
    ///   - now: 현재 시각입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 카드 상태를 짧게 표시하는 배지 문자열입니다.
    private func makeStatusBadgeText(
        snapshot: WeatherSnapshot,
        now: Date,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> String {
        if isFallback(snapshot: snapshot, now: now) {
            return localizedCopy("일부 보정", "Adjusted")
        }
        return localizedCopy("실시간", "Live")
    }

    /// 날씨 상세 카드가 보정/대기 상태인지 계산합니다.
    /// - Parameters:
    ///   - snapshot: 렌더링 대상 날씨 스냅샷입니다.
    ///   - now: 현재 시각입니다.
    /// - Returns: 실시간 관측이 아니거나 지연된 상태면 `true`입니다.
    private func isFallback(snapshot: WeatherSnapshot, now: Date) -> Bool {
        if snapshot.weatherSource != .live {
            return true
        }
        if snapshot.airQualitySource != .live {
            return true
        }
        return now.timeIntervalSince1970 - snapshot.observedAt > Constants.staleThreshold
    }

    /// 상세 날씨 카드와 미션 영향 카드의 역할을 분리해 설명하는 문구를 생성합니다.
    /// - Parameters:
    ///   - riskLevel: 현재 미션이 따르는 날씨 위험 단계입니다.
    ///   - localizedCopy: 현재 로케일에 맞는 한/영 문구를 선택하는 함수입니다.
    /// - Returns: 원시 날씨 카드 아래에 노출할 역할 분리 문구입니다.
    private func makeMissionHintText(
        riskLevel: IndoorWeatherRiskLevel,
        localizedCopy: (_ ko: String, _ en: String) -> String
    ) -> String {
        if riskLevel == .clear {
            return localizedCopy(
                "미션 영향 요약은 아래 카드에서 따로 보여줘요.",
                "The mission impact summary is shown separately in the next card."
            )
        }
        return localizedCopy(
            "\(riskLevel.displayTitle) 기준으로 바뀐 미션 영향은 아래 카드에서 따로 정리해요.",
            "Mission changes caused by \(riskLevel.displayTitle) are summarized separately in the next card."
        )
    }
}
