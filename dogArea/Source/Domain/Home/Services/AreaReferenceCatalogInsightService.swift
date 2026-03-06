import Foundation

struct AreaReferenceCatalogMetricItem: Identifiable, Hashable {
    let id: String
    let title: String
    let value: String
    let detail: String
}

struct AreaReferenceCatalogTag: Identifiable, Hashable {
    enum Style: String, Hashable {
        case primary
        case secondary
        case success
        case neutral
    }

    let id: String
    let title: String
    let style: Style
}

struct AreaReferenceCatalogRowViewData: Identifiable, Hashable {
    let id: String
    let name: String
    let areaText: String
    let tags: [AreaReferenceCatalogTag]
}

struct AreaReferenceCatalogSectionViewData: Identifiable, Hashable {
    let id: String
    let title: String
    let summaryText: String
    let rows: [AreaReferenceCatalogRowViewData]
}

struct AreaReferenceCatalogInsight: Hashable {
    let metrics: [AreaReferenceCatalogMetricItem]
    let currentBandTitle: String
    let currentBandBody: String
    let coverageSummaryText: String
    let displaySections: [AreaReferenceCatalogSectionViewData]
}

protocol AreaReferenceCatalogInsightServicing {
    /// 현재 면적과 비교군 카탈로그를 기준으로 AreaDetail 전용 인사이트를 계산합니다.
    /// - Parameters:
    ///   - currentArea: 현재 사용자가 확보한 영역입니다.
    ///   - nextGoal: 홈 화면에서 계산한 다음 목표입니다.
    ///   - sections: 카탈로그/참조 기준 원본 섹션 배열입니다.
    ///   - featuredCount: Featured 기준 개수입니다.
    /// - Returns: AreaDetail 화면에 표시할 카탈로그 요약/배지/행 데이터입니다.
    func makeInsight(
        currentArea: AreaMeter,
        nextGoal: AreaMeter?,
        sections: [AreaReferenceSection],
        featuredCount: Int
    ) -> AreaReferenceCatalogInsight
}

final class AreaReferenceCatalogInsightService: AreaReferenceCatalogInsightServicing {
    /// 현재 면적과 비교군 카탈로그를 기준으로 AreaDetail 전용 인사이트를 계산합니다.
    /// - Parameters:
    ///   - currentArea: 현재 사용자가 확보한 영역입니다.
    ///   - nextGoal: 홈 화면에서 계산한 다음 목표입니다.
    ///   - sections: 카탈로그/참조 기준 원본 섹션 배열입니다.
    ///   - featuredCount: Featured 기준 개수입니다.
    /// - Returns: AreaDetail 화면에 표시할 카탈로그 요약/배지/행 데이터입니다.
    func makeInsight(
        currentArea: AreaMeter,
        nextGoal: AreaMeter?,
        sections: [AreaReferenceSection],
        featuredCount: Int
    ) -> AreaReferenceCatalogInsight {
        let flattenedReferences = sections
            .flatMap(\.references)
            .sorted(using: KeyPathComparator(\.areaM2))
        let totalReferenceCount = flattenedReferences.count
        let currentReference = flattenedReferences.last { $0.areaM2 <= currentArea.area }
        let nextReference = matchNextReference(nextGoal: nextGoal, references: flattenedReferences)
            ?? flattenedReferences.first { $0.areaM2 > currentArea.area }

        return AreaReferenceCatalogInsight(
            metrics: makeMetricItems(
                sections: sections,
                totalReferenceCount: totalReferenceCount,
                featuredCount: featuredCount,
                nextReference: nextReference
            ),
            currentBandTitle: makeCurrentBandTitle(
                currentReference: currentReference,
                nextReference: nextReference
            ),
            currentBandBody: makeCurrentBandBody(
                currentArea: currentArea,
                currentReference: currentReference,
                nextReference: nextReference
            ),
            coverageSummaryText: makeCoverageSummaryText(
                sections: sections,
                totalReferenceCount: totalReferenceCount,
                featuredCount: featuredCount
            ),
            displaySections: makeDisplaySections(
                sections: sections,
                currentArea: currentArea,
                currentReference: currentReference,
                nextReference: nextReference,
                nextGoal: nextGoal
            )
        )
    }

    /// 카탈로그 상단 통계 카드에 표시할 메트릭 배열을 생성합니다.
    /// - Parameters:
    ///   - sections: 비교군 카탈로그 섹션 목록입니다.
    ///   - totalReferenceCount: 전체 기준 개수입니다.
    ///   - featuredCount: Featured 기준 개수입니다.
    ///   - nextReference: 현재 면적 다음에 오는 추천 기준입니다.
    /// - Returns: 화면 상단 4칸 카드에 사용할 메트릭 배열입니다.
    private func makeMetricItems(
        sections: [AreaReferenceSection],
        totalReferenceCount: Int,
        featuredCount: Int,
        nextReference: AreaReferenceItem?
    ) -> [AreaReferenceCatalogMetricItem] {
        [
            .init(
                id: "catalogs",
                title: "카탈로그",
                value: "\(sections.count)개",
                detail: "활성 비교군 묶음"
            ),
            .init(
                id: "references",
                title: "기준 수",
                value: "\(totalReferenceCount)개",
                detail: "탐색 가능한 비교 기준"
            ),
            .init(
                id: "featured",
                title: "Featured",
                value: "\(featuredCount)개",
                detail: "우선 추천 기준"
            ),
            .init(
                id: "next",
                title: "바로 다음",
                value: nextReference?.referenceName ?? "최상위 도달",
                detail: nextReference?.areaM2.calculatedAreaString ?? "새 기준 추가 필요"
            )
        ]
    }

    /// 현재 면적이 카탈로그상 어느 구간에 있는지 요약 제목을 생성합니다.
    /// - Parameters:
    ///   - currentReference: 현재 면적 이하에서 가장 가까운 기준입니다.
    ///   - nextReference: 현재 면적 초과 기준 중 가장 가까운 기준입니다.
    /// - Returns: 카탈로그 위치 요약 제목입니다.
    private func makeCurrentBandTitle(
        currentReference: AreaReferenceItem?,
        nextReference: AreaReferenceItem?
    ) -> String {
        switch (currentReference, nextReference) {
        case let (.some(currentReference), .some(nextReference)):
            return "\(currentReference.referenceName) 다음은 \(nextReference.referenceName)입니다."
        case let (.none, .some(nextReference)):
            return "아직 첫 기준 \(nextReference.referenceName) 전이에요."
        case let (.some(currentReference), .none):
            return "현재 \(currentReference.referenceName) 이상 구간에 도달했어요."
        case (.none, .none):
            return "표시할 비교군 기준이 아직 없어요."
        }
    }

    /// 현재 면적이 카탈로그상 어느 구간에 있는지 설명 문장을 생성합니다.
    /// - Parameters:
    ///   - currentArea: 현재 사용자가 확보한 영역입니다.
    ///   - currentReference: 현재 면적 이하에서 가장 가까운 기준입니다.
    ///   - nextReference: 현재 면적 초과 기준 중 가장 가까운 기준입니다.
    /// - Returns: 현재 위치와 다음 기준 간 관계를 설명하는 본문입니다.
    private func makeCurrentBandBody(
        currentArea: AreaMeter,
        currentReference: AreaReferenceItem?,
        nextReference: AreaReferenceItem?
    ) -> String {
        switch (currentReference, nextReference) {
        case let (.some(currentReference), .some(nextReference)):
            let gapText = max(0, nextReference.areaM2 - currentArea.area).calculatedAreaString
            return "현재 면적 \(currentArea.area.calculatedAreaString)은 \(currentReference.referenceName) 기준을 넘겼고, \(nextReference.referenceName)까지는 \(gapText) 남았습니다."
        case let (.none, .some(nextReference)):
            return "현재 면적 \(currentArea.area.calculatedAreaString)보다 큰 첫 기준은 \(nextReference.referenceName)입니다. 첫 비교군 진입을 목표로 경로를 조금만 더 넓혀보세요."
        case let (.some(currentReference), .none):
            return "\(currentReference.referenceName) 이후의 더 큰 기준은 현재 카탈로그에 없습니다. 다음 시즌 목표는 다른 카탈로그에서 찾는 편이 좋습니다."
        case (.none, .none):
            return "원격/로컬 비교군 기준을 아직 구성하지 못했습니다. 잠시 뒤 새로고침으로 카탈로그를 다시 받아보세요."
        }
    }

    /// 화면 하단 설명에 사용할 카탈로그 커버리지 요약 문구를 생성합니다.
    /// - Parameters:
    ///   - sections: 비교군 카탈로그 섹션 목록입니다.
    ///   - totalReferenceCount: 전체 기준 개수입니다.
    ///   - featuredCount: Featured 기준 개수입니다.
    /// - Returns: 카탈로그 범위와 우선순위를 설명하는 문구입니다.
    private func makeCoverageSummaryText(
        sections: [AreaReferenceSection],
        totalReferenceCount: Int,
        featuredCount: Int
    ) -> String {
        let catalogNames = sections.prefix(2).map(\.catalogName).joined(separator: ", ")
        if catalogNames.isEmpty {
            return "비교군 카탈로그가 비어 있어 다음 목표를 다시 계산하기 어렵습니다."
        }
        return "\(catalogNames) 기준으로 총 \(totalReferenceCount)개를 제공하고, 이 중 Featured \(featuredCount)개를 우선 추천합니다."
    }

    /// 카탈로그 섹션을 화면 표시용 행/배지 데이터로 변환합니다.
    /// - Parameters:
    ///   - sections: 비교군 카탈로그 섹션 목록입니다.
    ///   - currentArea: 현재 사용자가 확보한 영역입니다.
    ///   - currentReference: 현재 면적 이하에서 가장 가까운 기준입니다.
    ///   - nextReference: 현재 면적 초과 기준 중 가장 가까운 기준입니다.
    ///   - nextGoal: 홈 화면에서 계산한 다음 목표입니다.
    /// - Returns: 섹션/행/배지가 포함된 표시용 카탈로그 데이터입니다.
    private func makeDisplaySections(
        sections: [AreaReferenceSection],
        currentArea: AreaMeter,
        currentReference: AreaReferenceItem?,
        nextReference: AreaReferenceItem?,
        nextGoal: AreaMeter?
    ) -> [AreaReferenceCatalogSectionViewData] {
        sections.map { section in
            let reachedCount = section.references.filter { $0.areaM2 <= currentArea.area }.count
            let rows = section.references.prefix(6).map { reference in
                AreaReferenceCatalogRowViewData(
                    id: reference.id,
                    name: reference.referenceName,
                    areaText: reference.areaM2.calculatedAreaString,
                    tags: makeTags(
                        for: reference,
                        currentArea: currentArea,
                        currentReference: currentReference,
                        nextReference: nextReference,
                        nextGoal: nextGoal
                    )
                )
            }

            return AreaReferenceCatalogSectionViewData(
                id: section.id,
                title: section.catalogName,
                summaryText: "달성 \(reachedCount)개 · 남은 \(max(0, section.references.count - reachedCount))개",
                rows: rows
            )
        }
    }

    /// 개별 비교군 행에 표시할 상태 배지 목록을 생성합니다.
    /// - Parameters:
    ///   - reference: 배지를 계산할 비교군 기준입니다.
    ///   - currentArea: 현재 사용자가 확보한 영역입니다.
    ///   - currentReference: 현재 면적 이하에서 가장 가까운 기준입니다.
    ///   - nextReference: 현재 면적 초과 기준 중 가장 가까운 기준입니다.
    ///   - nextGoal: 홈 화면에서 계산한 다음 목표입니다.
    /// - Returns: 해당 비교군 행에 렌더링할 배지 배열입니다.
    private func makeTags(
        for reference: AreaReferenceItem,
        currentArea: AreaMeter,
        currentReference: AreaReferenceItem?,
        nextReference: AreaReferenceItem?,
        nextGoal: AreaMeter?
    ) -> [AreaReferenceCatalogTag] {
        var tags: [AreaReferenceCatalogTag] = []

        if reference.isFeatured {
            tags.append(.init(id: reference.id + "-featured", title: "FEATURED", style: .secondary))
        }
        if currentReference?.id == reference.id {
            tags.append(.init(id: reference.id + "-current", title: "현재 기준선", style: .neutral))
        } else if reference.areaM2 <= currentArea.area {
            tags.append(.init(id: reference.id + "-reached", title: "달성함", style: .success))
        }
        if nextReference?.id == reference.id {
            tags.append(.init(id: reference.id + "-next", title: "바로 다음", style: .primary))
        }
        if matchesNextGoal(reference, nextGoal: nextGoal) {
            tags.append(.init(id: reference.id + "-goal", title: "다음 목표", style: .primary))
        }
        return tags
    }

    /// 홈에서 계산된 다음 목표와 가장 잘 대응하는 카탈로그 기준을 찾습니다.
    /// - Parameters:
    ///   - nextGoal: 홈 화면에서 계산한 다음 목표입니다.
    ///   - references: 전체 카탈로그 기준 배열입니다.
    /// - Returns: 이름/면적이 가장 잘 일치하는 카탈로그 기준입니다.
    private func matchNextReference(
        nextGoal: AreaMeter?,
        references: [AreaReferenceItem]
    ) -> AreaReferenceItem? {
        guard let nextGoal else { return nil }
        if let exactName = references.first(where: { $0.referenceName == nextGoal.areaName }) {
            return exactName
        }

        let tolerance = max(1.0, nextGoal.area * 0.001)
        return references.first { abs($0.areaM2 - nextGoal.area) <= tolerance }
    }

    /// 카탈로그 기준이 홈의 다음 목표와 실질적으로 같은지 확인합니다.
    /// - Parameters:
    ///   - reference: 비교군 카탈로그 기준입니다.
    ///   - nextGoal: 홈 화면에서 계산한 다음 목표입니다.
    /// - Returns: 이름 또는 면적 허용 오차 기준으로 동일 목표라면 `true`입니다.
    private func matchesNextGoal(_ reference: AreaReferenceItem, nextGoal: AreaMeter?) -> Bool {
        guard let nextGoal else { return false }
        if reference.referenceName == nextGoal.areaName {
            return true
        }
        let tolerance = max(1.0, nextGoal.area * 0.001)
        return abs(reference.areaM2 - nextGoal.area) <= tolerance
    }
}
