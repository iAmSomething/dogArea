import Foundation

enum WeatherRiskLevelValue: String, CaseIterable, Codable {
    case clear
    case caution
    case bad
    case severe
}

enum WeatherSnapshotDataSource: String, Codable, Equatable {
    case live
    case fallback
    case unavailable
}

struct WeatherObservationLocationReference: Codable, Equatable {
    let latitude: Double
    let longitude: Double
}

struct WeatherSnapshot: Codable, Equatable {
    let level: WeatherRiskLevelValue
    let observedAt: TimeInterval
    let weatherSource: WeatherSnapshotDataSource
    let airQualitySource: WeatherSnapshotDataSource
    let location: WeatherObservationLocationReference
    let temperatureC: Double
    let apparentTemperatureC: Double
    let relativeHumidityPercent: Double
    let isPrecipitating: Bool
    let precipitationMMPerHour: Double
    let windMps: Double
    let pm2_5: Double?
    let pm10: Double?

    /// 공기질 세부 지표가 하나라도 존재하는지 반환합니다.
    /// - Returns: PM2.5 또는 PM10 값이 있으면 `true`입니다.
    var hasAirQualityMeasurements: Bool {
        pm2_5 != nil || pm10 != nil
    }
}

protocol WeatherSnapshotProviding {
    /// 좌표 기준 현재 날씨 스냅샷을 조회합니다.
    /// - Parameters:
    ///   - latitude: 조회 기준 위도입니다.
    ///   - longitude: 조회 기준 경도입니다.
    /// - Returns: 홈/맵/미션이 공통으로 사용할 현재 날씨 스냅샷입니다.
    func fetchSnapshot(latitude: Double, longitude: Double) async throws -> WeatherSnapshot
}

extension WeatherSnapshotProviding {
    /// 기존 risk-only 호출 경로와의 호환을 위해 날씨 스냅샷을 그대로 반환합니다.
    /// - Parameters:
    ///   - latitude: 조회 기준 위도입니다.
    ///   - longitude: 조회 기준 경도입니다.
    /// - Returns: 위험도와 원시 수치가 모두 담긴 날씨 스냅샷입니다.
    func fetchRisk(latitude: Double, longitude: Double) async throws -> WeatherRiskSnapshot {
        try await fetchSnapshot(latitude: latitude, longitude: longitude)
    }
}

typealias WeatherRiskProviding = WeatherSnapshotProviding
typealias WeatherRiskSnapshot = WeatherSnapshot
