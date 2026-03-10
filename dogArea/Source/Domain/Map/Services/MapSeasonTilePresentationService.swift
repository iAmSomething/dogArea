import Foundation
import MapKit

/// 시즌 타일 점령 지도에 필요한 셀 표현 계약입니다.
enum MapSeasonTileOccupationStatus: String {
    case maintained = "유지"
    case occupied = "점령"

    /// 상태가 지도에서 어떤 시각 규칙으로 읽혀야 하는지 설명합니다.
    /// - Returns: 점령/유지 상태의 시각 해설 문구입니다.
    var visualMeaningText: String {
        switch self {
        case .maintained:
            return "점선 테두리로 유지 상태를 보여줍니다."
        case .occupied:
            return "굵은 실선 테두리로 점령 상태를 보여줍니다."
        }
    }
}

/// 지도 본면에 렌더링할 시즌 타일 셀 표현 모델입니다.
struct MapSeasonTilePresentation: Identifiable, Equatable {
    let geohash: String
    let polygon: MKPolygon
    let centerCoordinate: CLLocationCoordinate2D
    let score: Double
    let intensityLevel: Int
    let intensityLabel: String
    let status: MapSeasonTileOccupationStatus

    var id: String { geohash }

    static func == (lhs: MapSeasonTilePresentation, rhs: MapSeasonTilePresentation) -> Bool {
        lhs.geohash == rhs.geohash
        && lhs.score == rhs.score
        && lhs.intensityLevel == rhs.intensityLevel
        && lhs.status == rhs.status
        && lhs.centerCoordinate.latitude == rhs.centerCoordinate.latitude
        && lhs.centerCoordinate.longitude == rhs.centerCoordinate.longitude
    }
}

/// 지도 범례/상단 카드에 노출할 시즌 타일 단계 정보입니다.
struct MapSeasonTileLegendPresentation: Identifiable, Equatable {
    let level: Int
    let title: String
    let description: String
    let status: MapSeasonTileOccupationStatus

    var id: String { "\(status.rawValue)-\(level)" }
}

/// 지도 본면 상단에 노출할 시즌 타일 점령 지도 요약입니다.
struct MapSeasonTileSummaryPresentation: Equatable {
    let title: String
    let countLine: String
    let meaningLine: String
    let intensityLine: String
    let walkContributionLine: String
    let selectionHintLine: String
    let topLevelLabel: String
    let occupiedCount: Int
    let maintainedCount: Int
    let legendItems: [MapSeasonTileLegendPresentation]
}

/// 지도 상단 chrome에 축약해서 노출할 시즌 타일 요약 모델입니다.
struct MapSeasonTileChromeSummaryPresentation: Equatable {
    let title: String
    let occupiedValue: String
    let maintainedValue: String
    let topLevelValue: String
    let accessibilitySummary: String
}

/// 지도에서 선택한 시즌 타일 하나를 해석해 보여줄 상세 패널 모델입니다.
struct MapSeasonTileDetailPresentation: Equatable {
    let title: String
    let statusTitle: String
    let intensityTitle: String
    let reasonLine: String
    let nextActionLine: String
    let contributionLine: String
}

/// 시즌 타일 점령 지도 시각 모델을 계산하는 계약입니다.
protocol MapSeasonTilePresentationServicing {
    /// 점수 값을 시즌 타일 4단계 강도로 변환합니다.
    /// - Parameter score: 셀에 누적된 정규화 점수입니다.
    /// - Returns: 0부터 3까지의 강도 단계입니다.
    func intensityLevel(for score: Double) -> Int

    /// 점수 값을 점령/유지 상태로 분류합니다.
    /// - Parameter score: 셀에 누적된 정규화 점수입니다.
    /// - Returns: 지도에 표시할 시즌 타일 상태입니다.
    func status(for score: Double) -> MapSeasonTileOccupationStatus

    /// Heatmap 셀 배열을 시즌 타일 점령 지도용 표현 모델로 변환합니다.
    /// - Parameter cells: 서버/집계 레이어에서 계산된 시즌 셀 배열입니다.
    /// - Returns: 지도 본면에 렌더링할 시즌 타일 셀 표현 배열입니다.
    func makeTilePresentations(from cells: [HeatmapCellDTO]) -> [MapSeasonTilePresentation]

    /// 지도 상단 카드/범례에서 사용할 시즌 타일 요약을 생성합니다.
    /// - Parameter tiles: 지도에 표시 중인 시즌 타일 셀 표현 배열입니다.
    /// - Returns: 시즌 점령 지도 의미와 현재 개수를 담은 요약 모델입니다.
    func makeSummaryPresentation(from tiles: [MapSeasonTilePresentation]) -> MapSeasonTileSummaryPresentation

    /// 지도 상단 chrome에 사용할 축약 요약을 생성합니다.
    /// - Parameter tiles: 지도에 표시 중인 시즌 타일 셀 표현 배열입니다.
    /// - Returns: 상단 chrome에 맞게 압축한 시즌 요약 모델입니다.
    func makeChromeSummaryPresentation(from tiles: [MapSeasonTilePresentation]) -> MapSeasonTileChromeSummaryPresentation

    /// 지도에서 선택한 시즌 타일의 상세 해설 모델을 생성합니다.
    /// - Parameter tile: 사용자가 선택한 시즌 타일 표현입니다.
    /// - Returns: 현재 상태, 이유, 다음 행동을 담은 상세 패널 모델입니다.
    func makeDetailPresentation(for tile: MapSeasonTilePresentation) -> MapSeasonTileDetailPresentation

    /// 시즌 타일 지도 범례에 사용할 단계 설명 배열을 생성합니다.
    /// - Returns: 단계/상태별 범례 설명 배열입니다.
    func makeLegendPresentations() -> [MapSeasonTileLegendPresentation]
}

/// Heatmap 셀을 사용자가 읽을 수 있는 시즌 점령 지도 표현으로 변환합니다.
final class MapSeasonTilePresentationService: MapSeasonTilePresentationServicing {
    /// 점수 값을 시즌 타일 4단계 강도로 변환합니다.
    /// - Parameter score: 셀에 누적된 정규화 점수입니다.
    /// - Returns: 0부터 3까지의 강도 단계입니다.
    func intensityLevel(for score: Double) -> Int {
        guard score > 0 else { return 0 }
        let level = Int(ceil(score * 4.0) - 1.0)
        return min(3, max(0, level))
    }

    /// 점수 값을 점령/유지 상태로 분류합니다.
    /// - Parameter score: 셀에 누적된 정규화 점수입니다.
    /// - Returns: 지도에 표시할 시즌 타일 상태입니다.
    func status(for score: Double) -> MapSeasonTileOccupationStatus {
        score >= 0.55 ? .occupied : .maintained
    }

    /// Heatmap 셀 배열을 시즌 타일 점령 지도용 표현 모델로 변환합니다.
    /// - Parameter cells: 서버/집계 레이어에서 계산된 시즌 셀 배열입니다.
    /// - Returns: 지도 본면에 렌더링할 시즌 타일 셀 표현 배열입니다.
    func makeTilePresentations(from cells: [HeatmapCellDTO]) -> [MapSeasonTilePresentation] {
        cells.compactMap { cell in
            guard let polygon = cell.seasonTilePolygon() else { return nil }
            let level = intensityLevel(for: cell.score)
            let status = status(for: cell.score)
            return MapSeasonTilePresentation(
                geohash: cell.geohash,
                polygon: polygon,
                centerCoordinate: cell.centerCoordinate,
                score: cell.score,
                intensityLevel: level,
                intensityLabel: "\(level + 1)단계",
                status: status
            )
        }
        .sorted { lhs, rhs in
            if lhs.intensityLevel == rhs.intensityLevel {
                return lhs.score < rhs.score
            }
            return lhs.intensityLevel < rhs.intensityLevel
        }
    }

    /// 지도 상단 카드/범례에서 사용할 시즌 타일 요약을 생성합니다.
    /// - Parameter tiles: 지도에 표시 중인 시즌 타일 셀 표현 배열입니다.
    /// - Returns: 시즌 점령 지도 의미와 현재 개수를 담은 요약 모델입니다.
    func makeSummaryPresentation(from tiles: [MapSeasonTilePresentation]) -> MapSeasonTileSummaryPresentation {
        let occupiedCount = tiles.filter { $0.status == .occupied }.count
        let maintainedCount = tiles.filter { $0.status == .maintained }.count
        let topLevel = (tiles.map(\.intensityLevel).max() ?? 0) + 1

        return MapSeasonTileSummaryPresentation(
            title: "시즌 점령 지도",
            countLine: "점령 \(occupiedCount)칸 · 유지 \(maintainedCount)칸",
            meaningLine: "굵은 테두리는 점령, 점선 테두리는 유지 상태예요.",
            intensityLine: "채움이 진할수록 더 강하게 점령한 칸이에요.",
            walkContributionLine: "산책 경로가 지나간 칸이 누적되며 다음 단계로 올라가요.",
            selectionHintLine: "칸을 눌러 왜 이런 상태인지와 다음 산책 힌트를 볼 수 있어요.",
            topLevelLabel: "최고 \(topLevel)단계",
            occupiedCount: occupiedCount,
            maintainedCount: maintainedCount,
            legendItems: makeLegendPresentations()
        )
    }

    /// 지도 상단 chrome에 사용할 축약 요약을 생성합니다.
    /// - Parameter tiles: 지도에 표시 중인 시즌 타일 셀 표현 배열입니다.
    /// - Returns: 상단 chrome에 맞게 압축한 시즌 요약 모델입니다.
    func makeChromeSummaryPresentation(from tiles: [MapSeasonTilePresentation]) -> MapSeasonTileChromeSummaryPresentation {
        let occupiedCount = tiles.filter { $0.status == .occupied }.count
        let maintainedCount = tiles.filter { $0.status == .maintained }.count
        let topLevel = (tiles.map(\.intensityLevel).max() ?? 0) + 1

        return MapSeasonTileChromeSummaryPresentation(
            title: "시즌 점령 지도",
            occupiedValue: "\(occupiedCount)칸",
            maintainedValue: "\(maintainedCount)칸",
            topLevelValue: "\(topLevel)단계",
            accessibilitySummary: "점령 \(occupiedCount)칸, 유지 \(maintainedCount)칸, 최고 \(topLevel)단계"
        )
    }

    /// 시즌 타일 지도 범례에 사용할 단계 설명 배열을 생성합니다.
    /// - Returns: 단계/상태별 범례 설명 배열입니다.
    func makeLegendPresentations() -> [MapSeasonTileLegendPresentation] {
        [
            .init(level: 0, title: "1단계 유지", description: "옅게 채워진 유지 칸", status: .maintained),
            .init(level: 1, title: "2단계 유지", description: "유지 중이지만 아직 약한 칸", status: .maintained),
            .init(level: 2, title: "3단계 점령", description: "막 점령권에 들어온 칸", status: .occupied),
            .init(level: 3, title: "4단계 점령", description: "가장 강하게 점령한 칸", status: .occupied)
        ]
    }

    /// 지도에서 선택한 시즌 타일의 상세 해설 모델을 생성합니다.
    /// - Parameter tile: 사용자가 선택한 시즌 타일 표현입니다.
    /// - Returns: 현재 상태, 이유, 다음 행동을 담은 상세 패널 모델입니다.
    func makeDetailPresentation(for tile: MapSeasonTilePresentation) -> MapSeasonTileDetailPresentation {
        MapSeasonTileDetailPresentation(
            title: detailTitle(for: tile),
            statusTitle: tile.status.rawValue,
            intensityTitle: tile.intensityLabel,
            reasonLine: reasonLine(for: tile),
            nextActionLine: nextActionLine(for: tile),
            contributionLine: contributionLine(for: tile)
        )
    }

    /// 시즌 타일 상세 패널의 제목을 생성합니다.
    /// - Parameter tile: 해설할 시즌 타일 표현입니다.
    /// - Returns: 현재 칸의 의미를 바로 읽을 수 있는 제목입니다.
    private func detailTitle(for tile: MapSeasonTilePresentation) -> String {
        switch (tile.status, tile.intensityLevel) {
        case (.occupied, 3):
            return "강하게 점령한 시즌 칸"
        case (.occupied, _):
            return "새로 점령권에 들어온 시즌 칸"
        case (.maintained, 0):
            return "유지 중인 준비 칸"
        case (.maintained, _):
            return "방어 중인 시즌 칸"
        }
    }

    /// 시즌 타일이 현재 상태로 보이는 이유를 사용자 문장으로 변환합니다.
    /// - Parameter tile: 해설할 시즌 타일 표현입니다.
    /// - Returns: 현재 상태가 만들어진 이유 설명입니다.
    private func reasonLine(for tile: MapSeasonTilePresentation) -> String {
        switch (tile.status, tile.intensityLevel) {
        case (.occupied, 3):
            return "이 칸은 이번 시즌 산책 기여가 충분히 누적돼 강하게 점령한 상태예요."
        case (.occupied, _):
            return "최근 산책 기여가 누적돼 이 칸이 점령 상태로 올라온 상태예요."
        case (.maintained, 0):
            return "기여가 조금 쌓였지만 아직 점령 전이라 유지 단계로 보이는 칸이에요."
        case (.maintained, _):
            return "최근 기여가 끊기지 않아 이 칸을 유지하고 있지만, 아직 더 채울 여지가 있어요."
        }
    }

    /// 다음 산책에서 추천할 행동 문구를 생성합니다.
    /// - Parameter tile: 해설할 시즌 타일 표현입니다.
    /// - Returns: 사용자가 다음 산책에서 취할 행동 힌트입니다.
    private func nextActionLine(for tile: MapSeasonTilePresentation) -> String {
        switch (tile.status, tile.intensityLevel) {
        case (.occupied, 3):
            return "다음 산책에서는 이 칸을 지나는 대신 주변 빈 칸까지 넓혀 점령 범위를 확장해 보세요."
        case (.occupied, _):
            return "다음 산책에서 이 칸을 한 번 더 지나가면 더 강한 점령 단계로 끌어올리기 쉬워요."
        case (.maintained, 0):
            return "다음 산책에서 이 칸을 다시 지나가면 유지 단계를 넘어 점령 단계로 올릴 수 있어요."
        case (.maintained, _):
            return "한두 번 더 이 칸을 지나가면 점령 상태로 전환될 가능성이 높아요."
        }
    }

    /// 현재 칸의 기여 강도를 짧게 요약합니다.
    /// - Parameter tile: 해설할 시즌 타일 표현입니다.
    /// - Returns: 단계와 점수 의미를 결합한 짧은 요약 문구입니다.
    private func contributionLine(for tile: MapSeasonTilePresentation) -> String {
        "현재 \(tile.intensityLabel) 강도예요. 채움이 더 진해질수록 이 칸의 시즌 기여가 강해집니다."
    }
}
