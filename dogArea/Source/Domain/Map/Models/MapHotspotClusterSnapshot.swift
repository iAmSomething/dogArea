//
//  MapHotspotClusterSnapshot.swift
//  dogArea
//
//  Created by Codex on 3/8/26.
//

import Foundation

/// 핫스팟 원본 입력이 실제로 바뀌었는지 추적하는 dataset fingerprint입니다.
struct MapHotspotClusterDatasetFingerprint: Equatable {
    let digestHex: String
    let hotspotCount: Int
    let aggregatedCount: Int
}

/// 핫스팟 렌더링에 영향을 주는 뷰포트 버킷 fingerprint입니다.
struct MapHotspotClusterViewportFingerprint: Equatable {
    let latitudeBucketIndex: Int?
    let longitudeBucketIndex: Int?
    let distanceBucketMeters: Int
    let viewportRadiusMeters: Int
}

/// 핫스팟 렌더링 정책 파라미터를 고정하는 tuning fingerprint입니다.
struct MapHotspotClusterTuningFingerprint: Equatable {
    let maxVisible: Int
    let pageMultiplier: Int
    let clusterDistanceThresholdMeters: Int
    let distanceRatioPermille: Int
    let minCellMeters: Int
    let maxCellMeters: Int
}

/// 재사용 가능한 핫스팟 클러스터 렌더링 결과 snapshot입니다.
struct MapHotspotClusterSnapshot {
    let datasetFingerprint: MapHotspotClusterDatasetFingerprint
    let viewportFingerprint: MapHotspotClusterViewportFingerprint
    let tuningFingerprint: MapHotspotClusterTuningFingerprint
    let sourceHotspotCount: Int
    let renderedNodeCount: Int
    let nodes: [NearbyHotspotRenderNode]
}
