//
//  MapHotspotClusterRenderingService.swift
//  dogArea
//
//  Created by Codex on 3/8/26.
//

import Foundation
import CoreLocation

/// 지도 핫스팟 클러스터 재계산을 dataset/viewport diff 기준으로 제한하는 계약입니다.
protocol MapHotspotClusterRenderingServicing {
    /// 현재 핫스팟 렌더링 입력 목록의 fingerprint를 생성합니다.
    /// - Parameter hotspots: 시각 상태까지 반영된 핫스팟 렌더링 입력 목록입니다.
    /// - Returns: 동일한 입력이면 같은 값을 갖는 dataset fingerprint입니다.
    func makeDatasetFingerprint(
        from hotspots: [NearbyHotspotRenderInput]
    ) -> MapHotspotClusterDatasetFingerprint

    /// 현재 카메라 상태를 핫스팟 렌더링용 뷰포트 fingerprint로 양자화합니다.
    /// - Parameters:
    ///   - viewportCenter: 현재 뷰포트 중심 좌표입니다.
    ///   - cameraDistance: 현재 카메라 거리(미터)입니다.
    /// - Returns: 의미 있는 뷰포트 변화만 구분하는 fingerprint입니다.
    func makeViewportFingerprint(
        viewportCenter: CLLocationCoordinate2D?,
        cameraDistance: Double
    ) -> MapHotspotClusterViewportFingerprint

    /// 렌더링 정책 파라미터를 fingerprint로 고정합니다.
    /// - Parameters:
    ///   - maxVisible: 최종 렌더링 최대 개수입니다.
    ///   - pageMultiplier: 후보 풀 확장 배수입니다.
    ///   - clusterDistanceThreshold: 클러스터 모드 전환 거리(미터)입니다.
    ///   - distanceRatio: 카메라 거리 대비 셀 거리 비율입니다.
    ///   - minCellMeters: 셀 거리 최소값(미터)입니다.
    ///   - maxCellMeters: 셀 거리 최대값(미터)입니다.
    /// - Returns: 렌더링 정책이 바뀌었는지 비교할 tuning fingerprint입니다.
    func makeTuningFingerprint(
        maxVisible: Int,
        pageMultiplier: Int,
        clusterDistanceThreshold: Double,
        distanceRatio: Double,
        minCellMeters: Double,
        maxCellMeters: Double
    ) -> MapHotspotClusterTuningFingerprint

    /// 기존 snapshot을 그대로 재사용할 수 있는지 판단합니다.
    /// - Parameters:
    ///   - snapshot: 이전에 계산된 핫스팟 렌더링 snapshot입니다.
    ///   - datasetFingerprint: 현재 입력 fingerprint입니다.
    ///   - viewportFingerprint: 현재 뷰포트 fingerprint입니다.
    ///   - tuningFingerprint: 현재 렌더링 정책 fingerprint입니다.
    /// - Returns: 세 fingerprint가 모두 같으면 `true`입니다.
    func canReuseSnapshot(
        _ snapshot: MapHotspotClusterSnapshot?,
        datasetFingerprint: MapHotspotClusterDatasetFingerprint,
        viewportFingerprint: MapHotspotClusterViewportFingerprint,
        tuningFingerprint: MapHotspotClusterTuningFingerprint
    ) -> Bool

    /// 현재 입력/뷰포트 기준의 핫스팟 렌더링 snapshot을 생성합니다.
    /// - Parameters:
    ///   - hotspots: 렌더링할 핫스팟 입력 목록입니다.
    ///   - datasetFingerprint: 현재 입력 fingerprint입니다.
    ///   - viewportFingerprint: 현재 뷰포트 fingerprint입니다.
    ///   - tuningFingerprint: 현재 렌더링 정책 fingerprint입니다.
    ///   - viewportCenter: 현재 뷰포트 중심 좌표입니다.
    ///   - cameraDistance: 현재 카메라 거리(미터)입니다.
    ///   - maxVisible: 최종 렌더링 최대 개수입니다.
    ///   - pageMultiplier: 후보 풀 확장 배수입니다.
    ///   - clusterDistanceThreshold: 클러스터 모드 전환 거리(미터)입니다.
    ///   - distanceRatio: 카메라 거리 대비 셀 거리 비율입니다.
    ///   - minCellMeters: 셀 거리 최소값(미터)입니다.
    ///   - maxCellMeters: 셀 거리 최대값(미터)입니다.
    /// - Returns: fingerprint와 최종 렌더링 노드를 함께 담은 snapshot입니다.
    func makeRenderSnapshot(
        hotspots: [NearbyHotspotRenderInput],
        datasetFingerprint: MapHotspotClusterDatasetFingerprint,
        viewportFingerprint: MapHotspotClusterViewportFingerprint,
        tuningFingerprint: MapHotspotClusterTuningFingerprint,
        viewportCenter: CLLocationCoordinate2D?,
        cameraDistance: Double,
        maxVisible: Int,
        pageMultiplier: Int,
        clusterDistanceThreshold: Double,
        distanceRatio: Double,
        minCellMeters: Double,
        maxCellMeters: Double
    ) -> MapHotspotClusterSnapshot
}

final class MapHotspotClusterRenderingService: MapHotspotClusterRenderingServicing {
    private let clusterAnnotationService: MapClusterAnnotationServicing

    /// 핫스팟 렌더링 gating 서비스를 생성합니다.
    /// - Parameter clusterAnnotationService: 실제 핫스팟 노드 계산에 사용할 클러스터 서비스입니다.
    init(clusterAnnotationService: MapClusterAnnotationServicing = MapClusterAnnotationService()) {
        self.clusterAnnotationService = clusterAnnotationService
    }

    /// 현재 핫스팟 렌더링 입력 목록의 fingerprint를 생성합니다.
    /// - Parameter hotspots: 시각 상태까지 반영된 핫스팟 렌더링 입력 목록입니다.
    /// - Returns: 동일한 입력이면 같은 값을 갖는 dataset fingerprint입니다.
    func makeDatasetFingerprint(
        from hotspots: [NearbyHotspotRenderInput]
    ) -> MapHotspotClusterDatasetFingerprint {
        var hash: UInt64 = 0xcbf29ce484222325
        let sortedHotspots = hotspots.sorted { lhs, rhs in
            lhs.id < rhs.id
        }

        for hotspot in sortedHotspots {
            mix(value: hotspot.id.utf8, into: &hash)
            mix(value: UInt64(hotspot.count), into: &hash)
            mix(value: hotspot.intensity.bitPattern, into: &hash)
            mix(value: hotspot.visualState.rawValue.utf8, into: &hash)
            mix(value: hotspot.centerCoordinate.latitude.bitPattern, into: &hash)
            mix(value: hotspot.centerCoordinate.longitude.bitPattern, into: &hash)
        }

        return MapHotspotClusterDatasetFingerprint(
            digestHex: String(format: "%016llx", hash),
            hotspotCount: hotspots.count,
            aggregatedCount: hotspots.reduce(0) { partialResult, hotspot in
                partialResult + hotspot.count
            }
        )
    }

    /// 현재 카메라 상태를 핫스팟 렌더링용 뷰포트 fingerprint로 양자화합니다.
    /// - Parameters:
    ///   - viewportCenter: 현재 뷰포트 중심 좌표입니다.
    ///   - cameraDistance: 현재 카메라 거리(미터)입니다.
    /// - Returns: 의미 있는 뷰포트 변화만 구분하는 fingerprint입니다.
    func makeViewportFingerprint(
        viewportCenter: CLLocationCoordinate2D?,
        cameraDistance: Double
    ) -> MapHotspotClusterViewportFingerprint {
        let normalizedDistance = normalizedCameraDistance(cameraDistance)
        let viewportRadius = makeViewportRadius(cameraDistance: normalizedDistance)
        let centerBucketMeters = centerBucketSizeMeters(viewportRadius: viewportRadius)
        let bucketedCenter = bucketedCenterIndexes(
            for: viewportCenter,
            bucketMeters: centerBucketMeters
        )
        let distanceBucketMeters = Int((normalizedDistance / 80.0).rounded() * 80.0)

        return MapHotspotClusterViewportFingerprint(
            latitudeBucketIndex: bucketedCenter?.0,
            longitudeBucketIndex: bucketedCenter?.1,
            distanceBucketMeters: distanceBucketMeters,
            viewportRadiusMeters: Int(viewportRadius.rounded())
        )
    }

    /// 렌더링 정책 파라미터를 fingerprint로 고정합니다.
    /// - Parameters:
    ///   - maxVisible: 최종 렌더링 최대 개수입니다.
    ///   - pageMultiplier: 후보 풀 확장 배수입니다.
    ///   - clusterDistanceThreshold: 클러스터 모드 전환 거리(미터)입니다.
    ///   - distanceRatio: 카메라 거리 대비 셀 거리 비율입니다.
    ///   - minCellMeters: 셀 거리 최소값(미터)입니다.
    ///   - maxCellMeters: 셀 거리 최대값(미터)입니다.
    /// - Returns: 렌더링 정책이 바뀌었는지 비교할 tuning fingerprint입니다.
    func makeTuningFingerprint(
        maxVisible: Int,
        pageMultiplier: Int,
        clusterDistanceThreshold: Double,
        distanceRatio: Double,
        minCellMeters: Double,
        maxCellMeters: Double
    ) -> MapHotspotClusterTuningFingerprint {
        MapHotspotClusterTuningFingerprint(
            maxVisible: maxVisible,
            pageMultiplier: pageMultiplier,
            clusterDistanceThresholdMeters: Int(clusterDistanceThreshold.rounded()),
            distanceRatioPermille: Int((distanceRatio * 1_000.0).rounded()),
            minCellMeters: Int(minCellMeters.rounded()),
            maxCellMeters: Int(maxCellMeters.rounded())
        )
    }

    /// 기존 snapshot을 그대로 재사용할 수 있는지 판단합니다.
    /// - Parameters:
    ///   - snapshot: 이전에 계산된 핫스팟 렌더링 snapshot입니다.
    ///   - datasetFingerprint: 현재 입력 fingerprint입니다.
    ///   - viewportFingerprint: 현재 뷰포트 fingerprint입니다.
    ///   - tuningFingerprint: 현재 렌더링 정책 fingerprint입니다.
    /// - Returns: 세 fingerprint가 모두 같으면 `true`입니다.
    func canReuseSnapshot(
        _ snapshot: MapHotspotClusterSnapshot?,
        datasetFingerprint: MapHotspotClusterDatasetFingerprint,
        viewportFingerprint: MapHotspotClusterViewportFingerprint,
        tuningFingerprint: MapHotspotClusterTuningFingerprint
    ) -> Bool {
        guard let snapshot else { return false }
        return snapshot.datasetFingerprint == datasetFingerprint
            && snapshot.viewportFingerprint == viewportFingerprint
            && snapshot.tuningFingerprint == tuningFingerprint
    }

    /// 현재 입력/뷰포트 기준의 핫스팟 렌더링 snapshot을 생성합니다.
    /// - Parameters:
    ///   - hotspots: 렌더링할 핫스팟 입력 목록입니다.
    ///   - datasetFingerprint: 현재 입력 fingerprint입니다.
    ///   - viewportFingerprint: 현재 뷰포트 fingerprint입니다.
    ///   - tuningFingerprint: 현재 렌더링 정책 fingerprint입니다.
    ///   - viewportCenter: 현재 뷰포트 중심 좌표입니다.
    ///   - cameraDistance: 현재 카메라 거리(미터)입니다.
    ///   - maxVisible: 최종 렌더링 최대 개수입니다.
    ///   - pageMultiplier: 후보 풀 확장 배수입니다.
    ///   - clusterDistanceThreshold: 클러스터 모드 전환 거리(미터)입니다.
    ///   - distanceRatio: 카메라 거리 대비 셀 거리 비율입니다.
    ///   - minCellMeters: 셀 거리 최소값(미터)입니다.
    ///   - maxCellMeters: 셀 거리 최대값(미터)입니다.
    /// - Returns: fingerprint와 최종 렌더링 노드를 함께 담은 snapshot입니다.
    func makeRenderSnapshot(
        hotspots: [NearbyHotspotRenderInput],
        datasetFingerprint: MapHotspotClusterDatasetFingerprint,
        viewportFingerprint: MapHotspotClusterViewportFingerprint,
        tuningFingerprint: MapHotspotClusterTuningFingerprint,
        viewportCenter: CLLocationCoordinate2D?,
        cameraDistance: Double,
        maxVisible: Int,
        pageMultiplier: Int,
        clusterDistanceThreshold: Double,
        distanceRatio: Double,
        minCellMeters: Double,
        maxCellMeters: Double
    ) -> MapHotspotClusterSnapshot {
        let normalizedDistance = normalizedCameraDistance(cameraDistance)
        let nodes = clusterAnnotationService.renderHotspots(
            hotspots: hotspots,
            viewportCenter: viewportCenter,
            cameraDistance: normalizedDistance,
            maxVisible: maxVisible,
            pageMultiplier: pageMultiplier,
            clusterDistanceThreshold: clusterDistanceThreshold,
            distanceRatio: distanceRatio,
            minCellMeters: minCellMeters,
            maxCellMeters: maxCellMeters
        )

        return MapHotspotClusterSnapshot(
            datasetFingerprint: datasetFingerprint,
            viewportFingerprint: viewportFingerprint,
            tuningFingerprint: tuningFingerprint,
            sourceHotspotCount: hotspots.count,
            renderedNodeCount: nodes.count,
            nodes: nodes
        )
    }

    /// 클러스터 계산에서 사용할 카메라 거리를 최소 유효값으로 보정합니다.
    /// - Parameter cameraDistance: 현재 지도 카메라 거리(미터)입니다.
    /// - Returns: 핫스팟 렌더링에 사용할 정규화된 거리(미터)입니다.
    private func normalizedCameraDistance(_ cameraDistance: Double) -> Double {
        guard cameraDistance.isFinite, cameraDistance > 0 else { return 180.0 }
        return max(180.0, cameraDistance)
    }

    /// 핫스팟 후보 필터링에 사용할 뷰포트 반경을 계산합니다.
    /// - Parameter cameraDistance: 정규화된 현재 카메라 거리(미터)입니다.
    /// - Returns: 핫스팟 후보 필터링 반경(미터)입니다.
    private func makeViewportRadius(cameraDistance: Double) -> Double {
        max(240.0, min(10_000.0, cameraDistance * 1.35))
    }

    /// 뷰포트 중심 이동을 의미 있는 diff로 묶을 버킷 크기를 계산합니다.
    /// - Parameter viewportRadius: 현재 뷰포트 반경(미터)입니다.
    /// - Returns: 중심 좌표 양자화에 사용할 버킷 크기(미터)입니다.
    private func centerBucketSizeMeters(viewportRadius: Double) -> Double {
        max(24.0, min(240.0, viewportRadius * 0.08))
    }

    /// 위경도 중심 좌표를 버킷 인덱스로 양자화합니다.
    /// - Parameters:
    ///   - center: 현재 뷰포트 중심 좌표입니다.
    ///   - bucketMeters: 버킷 크기(미터)입니다.
    /// - Returns: 위도/경도 버킷 인덱스 쌍입니다. 중심 좌표가 없으면 `nil`입니다.
    private func bucketedCenterIndexes(
        for center: CLLocationCoordinate2D?,
        bucketMeters: Double
    ) -> (Int, Int)? {
        guard let center else { return nil }
        guard center.latitude.isFinite, center.longitude.isFinite else { return nil }

        let latitudeDegreesPerMeter = 1.0 / 111_320.0
        let longitudeDegreesPerMeter = 1.0 / max(1.0, 111_320.0 * cos(center.latitude * .pi / 180.0))
        let latitudeBucketDegrees = bucketMeters * latitudeDegreesPerMeter
        let longitudeBucketDegrees = bucketMeters * longitudeDegreesPerMeter

        let latitudeIndex = Int((center.latitude / latitudeBucketDegrees).rounded())
        let longitudeIndex = Int((center.longitude / longitudeBucketDegrees).rounded())
        return (latitudeIndex, longitudeIndex)
    }

    /// FNV-1a 스타일 rolling hash에 문자열 바이트를 반영합니다.
    /// - Parameters:
    ///   - value: hash에 섞을 문자열 바이트 시퀀스입니다.
    ///   - hash: 누적 중인 64-bit hash 값입니다.
    private func mix<S: Sequence>(value: S, into hash: inout UInt64) where S.Element == UInt8 {
        for byte in value {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
    }

    /// FNV-1a 스타일 rolling hash에 64-bit 값을 반영합니다.
    /// - Parameters:
    ///   - value: hash에 섞을 64-bit 값입니다.
    ///   - hash: 누적 중인 64-bit hash 값입니다.
    private func mix(value: UInt64, into hash: inout UInt64) {
        withUnsafeBytes(of: value.littleEndian) { bytes in
            mix(value: bytes, into: &hash)
        }
    }
}
