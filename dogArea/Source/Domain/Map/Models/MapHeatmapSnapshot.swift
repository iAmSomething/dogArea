//
//  MapHeatmapSnapshot.swift
//  dogArea
//
//  Created by Codex on 3/8/26.
//

import Foundation

/// heatmap 입력 데이터셋이 실제로 바뀌었는지 추적하는 fingerprint입니다.
struct MapHeatmapDatasetFingerprint: Equatable {
    let digestHex: String
    let polygonCount: Int
    let pointCount: Int
}

/// 재사용 가능한 heatmap 집계 결과 snapshot입니다.
struct MapHeatmapAggregationSnapshot: Equatable {
    let datasetFingerprint: MapHeatmapDatasetFingerprint
    let computedAt: TimeInterval
    let validThrough: TimeInterval
    let sourcePointCount: Int
    let cells: [HeatmapCellDTO]
}
