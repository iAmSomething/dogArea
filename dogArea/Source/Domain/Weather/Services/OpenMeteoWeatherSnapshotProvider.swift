import Foundation

final class OpenMeteoWeatherSnapshotProvider: WeatherSnapshotProviding {
    private struct ForecastResponse: Decodable {
        struct Current: Decodable {
            let time: String
            let temperature2M: Double
            let apparentTemperature: Double
            let relativeHumidity2M: Double
            let precipitation: Double
            let windSpeed10M: Double

            enum CodingKeys: String, CodingKey {
                case time
                case temperature2M = "temperature_2m"
                case apparentTemperature = "apparent_temperature"
                case relativeHumidity2M = "relative_humidity_2m"
                case precipitation
                case windSpeed10M = "wind_speed_10m"
            }
        }

        let current: Current
    }

    private struct AirQualityResponse: Decodable {
        struct Current: Decodable {
            let pm10: Double?
            let pm25: Double?

            enum CodingKeys: String, CodingKey {
                case pm10
                case pm25 = "pm2_5"
            }
        }

        let current: Current
    }

    private let session: URLSession
    private let requestTimeout: TimeInterval

    /// Open-Meteo 기반 상세 날씨 스냅샷 공급자를 생성합니다.
    /// - Parameters:
    ///   - session: HTTP 요청에 사용할 URLSession입니다.
    ///   - requestTimeout: 단건 요청 타임아웃(초)입니다.
    init(session: URLSession = .shared, requestTimeout: TimeInterval = 6.0) {
        self.session = session
        self.requestTimeout = requestTimeout
    }

    /// 좌표 기준 현재 날씨 스냅샷을 조회합니다.
    /// - Parameters:
    ///   - latitude: 조회 기준 위도입니다.
    ///   - longitude: 조회 기준 경도입니다.
    /// - Returns: 홈/맵/미션 공용 상세 날씨 스냅샷입니다.
    func fetchSnapshot(latitude: Double, longitude: Double) async throws -> WeatherSnapshot {
        async let forecastResponse = fetchForecast(latitude: latitude, longitude: longitude)
        async let airQualityResponse = fetchAirQuality(latitude: latitude, longitude: longitude)

        let forecast = try await forecastResponse
        let airQuality = await airQualityResponse
        let observedAt = Self.parseObservedAt(forecast.current.time)
        let level = Self.score(
            precipitationMMPerHour: forecast.current.precipitation,
            temperatureC: forecast.current.temperature2M,
            windMps: forecast.current.windSpeed10M
        )

        return WeatherSnapshot(
            level: level,
            observedAt: observedAt,
            weatherSource: .live,
            airQualitySource: airQuality == nil ? .unavailable : .live,
            location: WeatherObservationLocationReference(
                latitude: latitude,
                longitude: longitude
            ),
            temperatureC: forecast.current.temperature2M,
            apparentTemperatureC: forecast.current.apparentTemperature,
            relativeHumidityPercent: forecast.current.relativeHumidity2M,
            isPrecipitating: forecast.current.precipitation > 0,
            precipitationMMPerHour: forecast.current.precipitation,
            windMps: forecast.current.windSpeed10M,
            pm2_5: airQuality?.current.pm25,
            pm10: airQuality?.current.pm10
        )
    }

    /// 예보 API에서 현재 기상 수치를 조회합니다.
    /// - Parameters:
    ///   - latitude: 조회 기준 위도입니다.
    ///   - longitude: 조회 기준 경도입니다.
    /// - Returns: 위험도 계산과 홈 상세 카드에 필요한 기상 응답입니다.
    private func fetchForecast(latitude: Double, longitude: Double) async throws -> ForecastResponse {
        let url = try makeForecastURL(latitude: latitude, longitude: longitude)
        let data = try await requestData(url: url)
        return try JSONDecoder().decode(ForecastResponse.self, from: data)
    }

    /// 공기질 API에서 PM 지표를 조회합니다.
    /// - Parameters:
    ///   - latitude: 조회 기준 위도입니다.
    ///   - longitude: 조회 기준 경도입니다.
    /// - Returns: PM 지표 응답이며, 공급자가 실패하면 `nil`을 반환합니다.
    private func fetchAirQuality(latitude: Double, longitude: Double) async -> AirQualityResponse? {
        do {
            let url = try makeAirQualityURL(latitude: latitude, longitude: longitude)
            let data = try await requestData(url: url)
            return try JSONDecoder().decode(AirQualityResponse.self, from: data)
        } catch {
            return nil
        }
    }

    /// Open-Meteo 예보 엔드포인트 URL을 생성합니다.
    /// - Parameters:
    ///   - latitude: 요청 위도입니다.
    ///   - longitude: 요청 경도입니다.
    /// - Returns: 상세 날씨 조회용 URL입니다.
    private func makeForecastURL(latitude: Double, longitude: Double) throws -> URL {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            .init(name: "latitude", value: String(latitude)),
            .init(name: "longitude", value: String(longitude)),
            .init(name: "current", value: "temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,wind_speed_10m"),
            .init(name: "wind_speed_unit", value: "ms"),
            .init(name: "timezone", value: "auto")
        ]
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        return url
    }

    /// Open-Meteo 공기질 엔드포인트 URL을 생성합니다.
    /// - Parameters:
    ///   - latitude: 요청 위도입니다.
    ///   - longitude: 요청 경도입니다.
    /// - Returns: 공기질 조회용 URL입니다.
    private func makeAirQualityURL(latitude: Double, longitude: Double) throws -> URL {
        var components = URLComponents(string: "https://air-quality-api.open-meteo.com/v1/air-quality")
        components?.queryItems = [
            .init(name: "latitude", value: String(latitude)),
            .init(name: "longitude", value: String(longitude)),
            .init(name: "current", value: "pm10,pm2_5"),
            .init(name: "timezone", value: "auto")
        ]
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        return url
    }

    /// 네트워크 응답 데이터를 조회하고 타임아웃/연결 유실에 한해 1회 재시도합니다.
    /// - Parameter url: 조회 대상 URL입니다.
    /// - Returns: 성공적으로 수신한 원시 응답 데이터입니다.
    private func requestData(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = requestTimeout

        var lastError: Error?
        for attempt in 0...1 {
            do {
                let (data, response) = try await session.data(for: request)
                if let httpResponse = response as? HTTPURLResponse,
                   (200..<300).contains(httpResponse.statusCode) == false {
                    throw URLError(.badServerResponse)
                }
                return data
            } catch {
                lastError = error
                let urlError = error as? URLError
                let shouldRetry = attempt == 0 && (urlError?.code == .timedOut || urlError?.code == .networkConnectionLost)
                guard shouldRetry else { throw error }
                try? await Task.sleep(nanoseconds: 350_000_000)
            }
        }

        throw lastError ?? URLError(.cannotParseResponse)
    }

    /// Open-Meteo 시각 문자열을 epoch seconds로 변환합니다.
    /// - Parameter value: Open-Meteo `current.time` 문자열입니다.
    /// - Returns: 파싱된 epoch seconds이며, 실패 시 현재 시각을 반환합니다.
    private static func parseObservedAt(_ value: String) -> TimeInterval {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: value) {
            return date.timeIntervalSince1970
        }
        let fallbackFormatter = DateFormatter()
        fallbackFormatter.locale = Locale(identifier: "en_US_POSIX")
        fallbackFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        fallbackFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        if let date = fallbackFormatter.date(from: value) {
            return date.timeIntervalSince1970
        }
        return Date().timeIntervalSince1970
    }

    /// 강수/기온/풍속 지표를 종합해 최종 날씨 위험도를 계산합니다.
    /// - Parameters:
    ///   - precipitationMMPerHour: 시간당 강수량(mm/h)입니다.
    ///   - temperatureC: 기온(섭씨)입니다.
    ///   - windMps: 풍속(m/s)입니다.
    /// - Returns: 지표별 최대 위험도 규칙으로 계산된 최종 위험도입니다.
    private static func score(
        precipitationMMPerHour: Double,
        temperatureC: Double,
        windMps: Double
    ) -> WeatherRiskLevelValue {
        let precipitationRisk = riskForPrecipitation(precipitationMMPerHour)
        let temperatureRisk = riskForTemperature(temperatureC)
        let windRisk = riskForWind(windMps)
        return [precipitationRisk, temperatureRisk, windRisk]
            .max(by: { $0.severityRank < $1.severityRank }) ?? .clear
    }

    /// 강수량 임계값 기반 위험도를 계산합니다.
    /// - Parameter value: 시간당 강수량(mm/h)입니다.
    /// - Returns: 강수량 기준 위험도입니다.
    private static func riskForPrecipitation(_ value: Double) -> WeatherRiskLevelValue {
        if value >= 12 { return .severe }
        if value >= 6 { return .bad }
        if value >= 1 { return .caution }
        return .clear
    }

    /// 기온 임계값 기반 위험도를 계산합니다.
    /// - Parameter value: 섭씨 기온입니다.
    /// - Returns: 기온 기준 위험도입니다.
    private static func riskForTemperature(_ value: Double) -> WeatherRiskLevelValue {
        if value >= 33 || value <= -8 { return .severe }
        if value >= 30 || value <= -3 { return .bad }
        if value >= 28 || value <= 0 { return .caution }
        return .clear
    }

    /// 풍속 임계값 기반 위험도를 계산합니다.
    /// - Parameter value: 풍속(m/s)입니다.
    /// - Returns: 풍속 기준 위험도입니다.
    private static func riskForWind(_ value: Double) -> WeatherRiskLevelValue {
        if value >= 14 { return .severe }
        if value >= 10 { return .bad }
        if value >= 6 { return .caution }
        return .clear
    }
}

private extension WeatherRiskLevelValue {
    var severityRank: Int {
        switch self {
        case .clear: return 0
        case .caution: return 1
        case .bad: return 2
        case .severe: return 3
        }
    }
}

typealias OpenMeteoWeatherRiskProvider = OpenMeteoWeatherSnapshotProvider
