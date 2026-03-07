import Foundation
import CryptoKit

/// 홈 실내 미션 반려견 컨텍스트 집계의 재사용 가능 snapshot을 계산하는 계약입니다.
protocol HomeIndoorMissionPetContextSnapshotServicing {
    /// 현재 홈 집계에 반영된 polygon 목록의 변경 여부를 추적할 fingerprint를 생성합니다.
    /// - Parameter polygons: 선택 반려견/전체 보기 정책이 반영된 홈 산책 polygon 목록입니다.
    /// - Returns: 순서 변화에 영향받지 않는 polygon 입력 fingerprint입니다.
    func makePolygonFingerprint(from polygons: [Polygon]) -> HomeIndoorMissionPetContextPolygonFingerprint

    /// 저장된 snapshot이 이번 요청 입력에 그대로 재사용 가능한지 판단합니다.
    /// - Parameters:
    ///   - snapshot: 이전 계산에서 보관 중인 집계 snapshot입니다.
    ///   - polygonFingerprint: 현재 홈 polygon 목록의 fingerprint입니다.
    ///   - selectedPetId: 현재 선택된 반려견 식별자입니다. 선택되지 않았으면 `nil`입니다.
    ///   - reference: 이번 실내 미션 계산의 기준 시각입니다.
    /// - Returns: 입력이 동일하고 snapshot의 시간 유효 구간 안이면 `true`입니다.
    func canReuseSnapshot(
        _ snapshot: HomeIndoorMissionPetContextAggregationSnapshot?,
        polygonFingerprint: HomeIndoorMissionPetContextPolygonFingerprint,
        selectedPetId: String?,
        reference: Date
    ) -> Bool

    /// 최근 14일/28일 산책 집계를 계산해 재사용 가능한 snapshot으로 반환합니다.
    /// - Parameters:
    ///   - polygons: 선택 반려견/전체 보기 정책이 반영된 홈 산책 polygon 목록입니다.
    ///   - polygonFingerprint: 현재 홈 polygon 목록의 fingerprint입니다.
    ///   - selectedPetId: 현재 선택된 반려견 식별자입니다. 선택되지 않았으면 `nil`입니다.
    ///   - reference: 이번 실내 미션 계산의 기준 시각입니다.
    /// - Returns: 다음 시간 경계까지 재사용 가능한 pet context 집계 snapshot입니다.
    func makeAggregationSnapshot(
        polygons: [Polygon],
        polygonFingerprint: HomeIndoorMissionPetContextPolygonFingerprint,
        selectedPetId: String?,
        reference: Date
    ) -> HomeIndoorMissionPetContextAggregationSnapshot
}

/// 홈 실내 미션 pet context 집계 입력이 실제로 바뀌었는지 추적하는 fingerprint입니다.
struct HomeIndoorMissionPetContextPolygonFingerprint: Equatable {
    let digestHex: String
    let polygonCount: Int
}

/// 홈 실내 미션 pet context의 재사용 가능한 집계 snapshot입니다.
struct HomeIndoorMissionPetContextAggregationSnapshot: Equatable {
    let polygonFingerprint: HomeIndoorMissionPetContextPolygonFingerprint
    let selectedPetId: String?
    let computedAt: TimeInterval
    let validThrough: TimeInterval?
    let recentDailyMinutes: Double
    let averageWeeklyWalkCount: Double
}

final class HomeIndoorMissionPetContextSnapshotService: HomeIndoorMissionPetContextSnapshotServicing {
    private let fourteenDayWindow: TimeInterval
    private let twentyEightDayWindow: TimeInterval

    /// 최근 산책 집계 snapshot 서비스의 기간 정책을 생성합니다.
    /// - Parameters:
    ///   - fourteenDayWindow: 최근 일일 평균 산책 시간을 계산할 lookback 길이(초)입니다.
    ///   - twentyEightDayWindow: 최근 주간 평균 산책 횟수를 계산할 lookback 길이(초)입니다.
    init(
        fourteenDayWindow: TimeInterval = 14 * 24 * 3600,
        twentyEightDayWindow: TimeInterval = 28 * 24 * 3600
    ) {
        self.fourteenDayWindow = fourteenDayWindow
        self.twentyEightDayWindow = twentyEightDayWindow
    }

    /// 현재 홈 집계에 반영된 polygon 목록의 변경 여부를 추적할 fingerprint를 생성합니다.
    /// - Parameter polygons: 선택 반려견/전체 보기 정책이 반영된 홈 산책 polygon 목록입니다.
    /// - Returns: 순서 변화에 영향받지 않는 polygon 입력 fingerprint입니다.
    func makePolygonFingerprint(from polygons: [Polygon]) -> HomeIndoorMissionPetContextPolygonFingerprint {
        HomeIndoorMissionPetContextPolygonFingerprint(
            digestHex: makeDigestHex(from: polygons),
            polygonCount: polygons.count
        )
    }

    /// 저장된 snapshot이 이번 요청 입력에 그대로 재사용 가능한지 판단합니다.
    /// - Parameters:
    ///   - snapshot: 이전 계산에서 보관 중인 집계 snapshot입니다.
    ///   - polygonFingerprint: 현재 홈 polygon 목록의 fingerprint입니다.
    ///   - selectedPetId: 현재 선택된 반려견 식별자입니다. 선택되지 않았으면 `nil`입니다.
    ///   - reference: 이번 실내 미션 계산의 기준 시각입니다.
    /// - Returns: 입력이 동일하고 snapshot의 시간 유효 구간 안이면 `true`입니다.
    func canReuseSnapshot(
        _ snapshot: HomeIndoorMissionPetContextAggregationSnapshot?,
        polygonFingerprint: HomeIndoorMissionPetContextPolygonFingerprint,
        selectedPetId: String?,
        reference: Date
    ) -> Bool {
        guard let snapshot else { return false }
        guard snapshot.polygonFingerprint == polygonFingerprint else { return false }
        guard snapshot.selectedPetId == selectedPetId else { return false }

        let referenceTimestamp = reference.timeIntervalSince1970
        guard referenceTimestamp >= snapshot.computedAt else { return false }
        guard let validThrough = snapshot.validThrough else { return true }
        return referenceTimestamp <= validThrough
    }

    /// 최근 14일/28일 산책 집계를 계산해 재사용 가능한 snapshot으로 반환합니다.
    /// - Parameters:
    ///   - polygons: 선택 반려견/전체 보기 정책이 반영된 홈 산책 polygon 목록입니다.
    ///   - polygonFingerprint: 현재 홈 polygon 목록의 fingerprint입니다.
    ///   - selectedPetId: 현재 선택된 반려견 식별자입니다. 선택되지 않았으면 `nil`입니다.
    ///   - reference: 이번 실내 미션 계산의 기준 시각입니다.
    /// - Returns: 다음 시간 경계까지 재사용 가능한 pet context 집계 snapshot입니다.
    func makeAggregationSnapshot(
        polygons: [Polygon],
        polygonFingerprint: HomeIndoorMissionPetContextPolygonFingerprint,
        selectedPetId: String?,
        reference: Date
    ) -> HomeIndoorMissionPetContextAggregationSnapshot {
        let referenceTimestamp = reference.timeIntervalSince1970
        let recentCutoff = referenceTimestamp - fourteenDayWindow
        let monthlyCutoff = referenceTimestamp - twentyEightDayWindow

        let recentPolygons = polygons.filter { $0.createdAt >= recentCutoff }
        let monthlyPolygons = polygons.filter { $0.createdAt >= monthlyCutoff }
        let totalRecentMinutes = recentPolygons.reduce(0.0) { partial, polygon in
            partial + max(0, polygon.walkingTime) / 60.0
        }

        return HomeIndoorMissionPetContextAggregationSnapshot(
            polygonFingerprint: polygonFingerprint,
            selectedPetId: selectedPetId,
            computedAt: referenceTimestamp,
            validThrough: makeNextInvalidationTimestamp(
                recentPolygons: recentPolygons,
                monthlyPolygons: monthlyPolygons
            ),
            recentDailyMinutes: totalRecentMinutes / 14.0,
            averageWeeklyWalkCount: Double(monthlyPolygons.count) / 4.0
        )
    }

    /// polygon 목록을 순서와 무관하게 식별하는 SHA256 digest를 계산합니다.
    /// - Parameter polygons: 홈 실내 미션 집계에 사용 중인 polygon 목록입니다.
    /// - Returns: 동일 membership이면 같은 값을 갖는 hex digest 문자열입니다.
    private func makeDigestHex(from polygons: [Polygon]) -> String {
        let raw = polygons
            .map { polygon in
                "\(polygon.id.uuidString.lowercased())|\(polygon.createdAt.bitPattern)|\(polygon.walkingTime.bitPattern)"
            }
            .sorted()
            .joined(separator: "\n")
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// 현재 snapshot 결과가 바뀔 수 있는 가장 이른 시간 경계를 계산합니다.
    /// - Parameters:
    ///   - recentPolygons: 최근 14일 평균에 포함된 polygon 목록입니다.
    ///   - monthlyPolygons: 최근 28일 평균에 포함된 polygon 목록입니다.
    /// - Returns: 결과가 달라질 수 있는 가장 이른 시각이며, 더 이상 만료 이벤트가 없으면 `nil`입니다.
    private func makeNextInvalidationTimestamp(
        recentPolygons: [Polygon],
        monthlyPolygons: [Polygon]
    ) -> TimeInterval? {
        let recentExpiry = recentPolygons.map { $0.createdAt + fourteenDayWindow }.min()
        let monthlyExpiry = monthlyPolygons.map { $0.createdAt + twentyEightDayWindow }.min()

        switch (recentExpiry, monthlyExpiry) {
        case let (lhs?, rhs?):
            return min(lhs, rhs)
        case let (lhs?, nil):
            return lhs
        case let (nil, rhs?):
            return rhs
        case (nil, nil):
            return nil
        }
    }
}
