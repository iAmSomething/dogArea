import Foundation

struct WalkListDetailPresentationService: WalkListDetailPresentationServicing {
    /// 산책 상세 화면에 필요한 표시 전용 스냅샷을 구성합니다.
    /// - Parameters:
    ///   - model: 현재 상세 화면이 표현할 산책 기록 모델입니다.
    ///   - sessionMetadata: 종료 사유/종료 시각 등 세션 메타데이터입니다.
    ///   - pets: 현재 사용자에게 연결된 반려견 목록입니다.
    ///   - isMeter: 영역 넓이를 ㎡ 기준으로 보여줄지 여부입니다.
    ///   - selectedLocationID: 현재 사용자가 강조 중인 포인트 식별자입니다.
    /// - Returns: 상세 화면의 각 섹션이 바로 사용할 수 있는 스냅샷입니다.
    func makeSnapshot(
        model: WalkDataModel,
        sessionMetadata: WalkSessionMetadata?,
        pets: [PetInfo],
        isMeter: Bool,
        selectedLocationID: UUID?
    ) -> WalkListDetailPresentationSnapshot {
        let petName = resolvePetName(model: model, sessionMetadata: sessionMetadata, pets: pets)
        let visibleLocations = makeVisibleTimelineLocations(
            locations: model.locations,
            selectedLocationID: selectedLocationID
        )
        let effectiveSelectedID = selectedLocationID ?? visibleLocations.first?.id ?? model.locations.first?.id
        return WalkListDetailPresentationSnapshot(
            hero: makeHero(model: model, petName: petName, sessionMetadata: sessionMetadata),
            metrics: makeMetrics(model: model, sessionMetadata: sessionMetadata, isMeter: isMeter),
            timeline: makeTimeline(
                locations: visibleLocations,
                selectedLocationID: effectiveSelectedID
            ),
            metaRows: makeMetaRows(model: model, petName: petName, sessionMetadata: sessionMetadata),
            selectedPointSummary: makeSelectedPointSummary(
                locations: visibleLocations,
                selectedLocationID: effectiveSelectedID
            ),
            timelineFootnote: visibleLocations.count < model.locations.count ? "긴 기록이라 대표 시점만 먼저 보여주고 있어요." : nil,
            hasMapContent: model.locations.isEmpty == false && model.toPolygon().polygon != nil
        )
    }

    /// 헤더 카드에 필요한 요약 문구를 구성합니다.
    /// - Parameters:
    ///   - model: 현재 산책 기록 모델입니다.
    ///   - petName: 화면에 노출할 반려견 이름입니다.
    ///   - sessionMetadata: 종료 메타데이터입니다.
    /// - Returns: 헤더 카드에 사용할 요약 모델입니다.
    private func makeHero(
        model: WalkDataModel,
        petName: String,
        sessionMetadata: WalkSessionMetadata?
    ) -> WalkListDetailHeroModel {
        let pointCount = model.locations.count
        let subtitle = petName == "반려견 미지정"
            ? "\(model.walkDuration.simpleWalkingTimeInterval) 동안 \(pointCount)개 포인트를 남겼어요."
            : "\(petName)와 \(model.walkDuration.simpleWalkingTimeInterval) 동안 \(pointCount)개 포인트를 남겼어요."
        return WalkListDetailHeroModel(
            badge: "산책 회고",
            title: formatHeaderTitle(model.createdAt),
            subtitle: subtitle,
            petBadge: petName,
            statusBadge: sessionMetadata.map { endReasonText($0.endReason) },
            loopSummaryTitle: "이 산책이 남기는 것",
            loopSummaryBody: "이 기록은 경로, 영역, 시간, 포인트 데이터가 남은 산책 결과예요. 산책 목록에서 다시 보고, 홈 목표와 시즌, 오늘 행동 해석까지 같은 기록을 기준으로 이어집니다."
        )
    }

    /// 핵심 수치 카드를 구성합니다.
    /// - Parameters:
    ///   - model: 현재 산책 기록 모델입니다.
    ///   - sessionMetadata: 종료 메타데이터입니다.
    ///   - isMeter: ㎡ 표시 여부입니다.
    /// - Returns: 수치 카드 모델 배열입니다.
    private func makeMetrics(
        model: WalkDataModel,
        sessionMetadata: WalkSessionMetadata?,
        isMeter: Bool
    ) -> [WalkListDetailMetricModel] {
        var metrics: [WalkListDetailMetricModel] = [
            WalkListDetailMetricModel(
                id: "area",
                title: "영역 넓이",
                value: formattedArea(areaSize: model.walkArea, isPyong: isMeter == false),
                detail: isMeter ? "탭해서 평으로 전환" : "탭해서 ㎡로 전환",
                tone: .warm
            ),
            WalkListDetailMetricModel(
                id: "duration",
                title: "산책 시간",
                value: model.walkDuration.simpleWalkingTimeInterval,
                detail: "시작 \(formatTime(model.createdAt))",
                tone: .neutral
            ),
            WalkListDetailMetricModel(
                id: "points",
                title: "포인트 수",
                value: "\(model.locations.count)개",
                detail: pointRoleBreakdown(model.locations),
                tone: .accent
            )
        ]
        if let sessionMetadata {
            metrics.append(
                WalkListDetailMetricModel(
                    id: "end",
                    title: "종료 시각",
                    value: formatTime(sessionMetadata.endedAt),
                    detail: endReasonText(sessionMetadata.endReason),
                    tone: .neutral
                )
            )
        }
        return metrics
    }

    /// 포인트 칩으로 노출할 대표 시점을 추립니다.
    /// - Parameters:
    ///   - locations: 전체 포인트 목록입니다.
    ///   - selectedLocationID: 현재 강조 중인 포인트 식별자입니다.
    /// - Returns: 타임라인에 노출할 포인트 목록입니다.
    private func makeVisibleTimelineLocations(
        locations: [WalkPosition],
        selectedLocationID: UUID?
    ) -> [WalkPosition] {
        guard locations.count > 12 else { return locations }

        var selectedIndices: Set<Int> = [0, locations.count - 1]
        let strideValue = max(Int(ceil(Double(locations.count - 2) / 8.0)), 1)
        var index = 0
        while index < locations.count {
            selectedIndices.insert(index)
            index += strideValue
        }
        if let selectedLocationID,
           let selectedIndex = locations.firstIndex(where: { $0.id == selectedLocationID }) {
            selectedIndices.insert(selectedIndex)
        }

        return selectedIndices.sorted().compactMap { locations[safe: $0] }
    }

    /// 표시용 포인트 타임라인 칩 모델을 생성합니다.
    /// - Parameters:
    ///   - locations: 타임라인에 노출할 포인트 목록입니다.
    ///   - selectedLocationID: 현재 강조 중인 포인트 식별자입니다.
    /// - Returns: 포인트 칩 모델 배열입니다.
    private func makeTimeline(
        locations: [WalkPosition],
        selectedLocationID: UUID?
    ) -> [WalkListDetailTimelineChipModel] {
        var markCount = 0
        var routeCount = 0
        return locations.enumerated().map { index, location in
            let title = makePointTitle(
                location: location,
                index: index,
                totalCount: locations.count,
                markCount: &markCount,
                routeCount: &routeCount
            )
            return WalkListDetailTimelineChipModel(
                id: location.id,
                title: title,
                subtitle: formatTime(location.createdAt),
                roleLabel: location.pointRole == .mark ? "영역 표시" : "이동 경로",
                isSelected: location.id == selectedLocationID
            )
        }
    }

    /// 메타 카드에 사용할 행 모델을 구성합니다.
    /// - Parameters:
    ///   - model: 현재 산책 기록 모델입니다.
    ///   - petName: 화면에 노출할 반려견 이름입니다.
    ///   - sessionMetadata: 종료 메타데이터입니다.
    /// - Returns: 메타 카드 행 모델 배열입니다.
    private func makeMetaRows(
        model: WalkDataModel,
        petName: String,
        sessionMetadata: WalkSessionMetadata?
    ) -> [WalkListDetailMetaRowModel] {
        var rows: [WalkListDetailMetaRowModel] = [
            .init(id: "pet", title: "반려견", value: petName),
            .init(id: "startedAt", title: "시작 시각", value: formatDateTime(model.createdAt)),
            .init(id: "pointSummary", title: "기록 요약", value: "포인트 \(model.locations.count)개 · \(pointRoleBreakdown(model.locations))")
        ]
        if let sessionMetadata {
            rows.append(.init(id: "endedAt", title: "종료 시각", value: formatDateTime(sessionMetadata.endedAt)))
            rows.append(.init(id: "endReason", title: "종료 사유", value: endReasonText(sessionMetadata.endReason)))
        } else {
            rows.append(.init(id: "endReasonFallback", title: "종료 정보", value: "종료 메타 없이 저장된 기록이에요."))
        }
        return rows
    }

    /// 현재 강조 중인 포인트를 한 줄 요약으로 반환합니다.
    /// - Parameters:
    ///   - locations: 타임라인에 노출 중인 포인트 목록입니다.
    ///   - selectedLocationID: 현재 강조 중인 포인트 식별자입니다.
    /// - Returns: 지도 상단에 노출할 포인트 요약 문자열입니다.
    private func makeSelectedPointSummary(
        locations: [WalkPosition],
        selectedLocationID: UUID?
    ) -> String {
        guard let selectedLocation = locations.first(where: { $0.id == selectedLocationID }) ?? locations.first else {
            return "포인트가 없어 지도 강조를 만들 수 없어요."
        }
        let roleText = selectedLocation.pointRole == .mark ? "영역 표시" : "이동 경로"
        return "현재 보는 시점 · \(roleText) · \(formatTime(selectedLocation.createdAt))"
    }

    /// 산책 기록에 연결된 반려견 이름을 결정합니다.
    /// - Parameters:
    ///   - model: 현재 산책 기록 모델입니다.
    ///   - sessionMetadata: 종료 메타데이터입니다.
    ///   - pets: 사용자 반려견 목록입니다.
    /// - Returns: 화면에 노출할 반려견 이름입니다.
    private func resolvePetName(
        model: WalkDataModel,
        sessionMetadata: WalkSessionMetadata?,
        pets: [PetInfo]
    ) -> String {
        let petId = sessionMetadata?.petId ?? model.petId
        guard let petId,
              let pet = pets.first(where: { $0.petId == petId }) else {
            return "반려견 미지정"
        }
        return pet.petName
    }

    /// 포인트 역할별 카운트 요약 문구를 만듭니다.
    /// - Parameter locations: 현재 산책 기록의 포인트 목록입니다.
    /// - Returns: 영역 표시/이동 경로 개수를 설명하는 문자열입니다.
    private func pointRoleBreakdown(_ locations: [WalkPosition]) -> String {
        let markCount = locations.filter { $0.pointRole == .mark }.count
        let routeCount = locations.filter { $0.pointRole == .route }.count
        return "영역 \(markCount) · 이동 \(routeCount)"
    }

    /// 포인트 역할과 순번에 따라 사용자 친화적인 제목을 만듭니다.
    /// - Parameters:
    ///   - location: 현재 포인트입니다.
    ///   - index: 타임라인 내 현재 인덱스입니다.
    ///   - totalCount: 타임라인 전체 포인트 개수입니다.
    ///   - markCount: 영역 표시 포인트 누적 카운트입니다.
    ///   - routeCount: 이동 경로 포인트 누적 카운트입니다.
    /// - Returns: 칩 상단에 노출할 제목 문자열입니다.
    private func makePointTitle(
        location: WalkPosition,
        index: Int,
        totalCount: Int,
        markCount: inout Int,
        routeCount: inout Int
    ) -> String {
        if index == 0 { return "시작" }
        if index == totalCount - 1 {
            return location.pointRole == .mark ? "마지막 표시" : "마지막 이동"
        }
        switch location.pointRole {
        case .mark:
            markCount += 1
            return "영역 \(markCount)"
        case .route:
            routeCount += 1
            return "이동 \(routeCount)"
        }
    }

    /// 종료 사유 열거값을 사용자 문구로 변환합니다.
    /// - Parameter reason: 저장된 종료 사유입니다.
    /// - Returns: 화면에 노출할 종료 사유 문자열입니다.
    private func endReasonText(_ reason: WalkSessionEndReason) -> String {
        switch reason {
        case .manual:
            return "수동 종료"
        case .autoInactive:
            return "무이동 자동 종료"
        case .autoTimeout:
            return "시간 제한 자동 종료"
        case .recoveryEstimated:
            return "복구 추정 종료"
        }
    }

    /// 헤더 카드 제목용 날짜/시간 문자열을 구성합니다.
    /// - Parameter createdAt: 산책 시작 시각입니다.
    /// - Returns: 상단 제목에 사용할 날짜/시간 문자열입니다.
    private func formatHeaderTitle(_ createdAt: TimeInterval) -> String {
        Self.headerDateFormatter.string(from: Date(timeIntervalSince1970: createdAt))
    }

    /// 시간만 짧게 보여주는 문자열을 반환합니다.
    /// - Parameter value: 변환할 시각입니다.
    /// - Returns: `오전/오후 h:mm` 형식 문자열입니다.
    private func formatTime(_ value: TimeInterval) -> String {
        Self.timeFormatter.string(from: Date(timeIntervalSince1970: value))
    }

    /// 메타 카드용 날짜/시간 문자열을 반환합니다.
    /// - Parameter value: 변환할 시각입니다.
    /// - Returns: `M월 d일 오전/오후 h:mm` 형식 문자열입니다.
    private func formatDateTime(_ value: TimeInterval) -> String {
        Self.dateTimeFormatter.string(from: Date(timeIntervalSince1970: value))
    }

    /// 영역 넓이를 ㎡/평 기준 문자열로 포맷합니다.
    /// - Parameters:
    ///   - areaSize: 원본 영역 넓이(m²)입니다.
    ///   - isPyong: 평 단위 변환 여부입니다.
    /// - Returns: 선택 단위가 적용된 영역 문자열입니다.
    private func formattedArea(areaSize: Double, isPyong: Bool) -> String {
        var string = String(format: "%.2f", areaSize) + "㎡"
        if areaSize > 10000.0 {
            string = String(format: "%.2f", areaSize / 10000) + "만 ㎡"
        }
        if areaSize > 100000.0 {
            string = String(format: "%.2f", areaSize / 1000000) + "k㎡"
        }
        if isPyong {
            if areaSize / 3.3 > 10000 {
                return String(format: "%.1f", areaSize / 33333) + "만 평"
            }
            return String(format: "%.1f", areaSize / 3.3) + "평"
        }
        return string
    }

    private static let headerDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 a h:mm 산책"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일 a h:mm"
        return formatter
    }()
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
