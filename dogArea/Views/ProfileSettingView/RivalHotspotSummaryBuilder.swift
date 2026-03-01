import Foundation

/// 핫스팟 카드 상단 요약 데이터입니다.
struct RivalHotspotSummary {
    let maxIntensityText: String
    let lastUpdatedText: String
    let previewRows: [RivalTabViewModel.HotspotPreviewRow]
}

/// 핫스팟 목록을 UI 요약 데이터로 변환합니다.
enum RivalHotspotSummaryBuilder {
    /// 핫스팟 목록으로 카드 요약 정보를 생성합니다.
    /// - Parameters:
    ///   - hotspots: 원본 핫스팟 목록입니다.
    ///   - referenceDate: 마지막 업데이트 시각 텍스트 계산 기준 시각입니다.
    /// - Returns: 카드에 렌더링할 최대 강도/업데이트 시각/프리뷰 행 묶음입니다.
    static func build(
        from hotspots: [NearbyHotspotDTO],
        referenceDate: Date = Date()
    ) -> RivalHotspotSummary {
        guard let maximum = hotspots.map(\.intensity).max() else {
            return RivalHotspotSummary(maxIntensityText: "없음", lastUpdatedText: "-", previewRows: [])
        }

        let maxIntensityText: String
        if maximum >= 0.67 {
            maxIntensityText = "높음"
        } else if maximum >= 0.34 {
            maxIntensityText = "보통"
        } else {
            maxIntensityText = "낮음"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let lastUpdatedText = formatter.string(from: referenceDate)

        let previewRows = hotspots
            .sorted(by: { $0.intensity > $1.intensity })
            .prefix(3)
            .map { hotspot in
                RivalTabViewModel.HotspotPreviewRow(
                    title: "격자 \(hotspot.geohash.prefix(5))",
                    value: "\(Int(hotspot.intensity * 100))% · \(hotspot.count)명"
                )
            }

        return RivalHotspotSummary(
            maxIntensityText: maxIntensityText,
            lastUpdatedText: lastUpdatedText,
            previewRows: previewRows
        )
    }
}
