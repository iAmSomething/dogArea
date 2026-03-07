//
//  HomeAreaAggregationService.swift
//  dogArea
//
//  Created by Codex on 3/7/26.
//

import Foundation

protocol HomeAreaAggregationServicing {
    /// 선택 반려견/전체 보기 상태를 반영해 홈 화면에 노출할 산책 기록만 필터링합니다.
    /// - Parameters:
    ///   - polygons: 원본 산책 기록 목록입니다.
    ///   - selectedPetId: 현재 선택된 반려견 식별자입니다. 선택되지 않았으면 `nil`입니다.
    ///   - showsAllRecords: 전체 기록 강제 표시 상태입니다.
    /// - Returns: 홈 화면 집계에 사용할 산책 기록 목록입니다.
    func filteredPolygons(
        from polygons: [Polygon],
        selectedPetId: String?,
        showsAllRecords: Bool
    ) -> [Polygon]

    /// 홈 화면 현재 영역 모델을 생성합니다.
    /// - Parameters:
    ///   - totalArea: 현재 누적 산책 영역(`m²`)입니다.
    ///   - selectedPetNameWithYi: 조사 보정이 적용된 반려견 이름입니다.
    /// - Returns: 홈 화면 현재 영역 카드에 표시할 `AreaMeter`입니다.
    func makeCurrentArea(totalArea: Double, selectedPetNameWithYi: String) -> AreaMeter

    /// 현재 영역 바로 아래의 비교군을 계산합니다.
    /// - Parameters:
    ///   - currentArea: 현재 누적 영역 모델입니다.
    ///   - areaCollection: 기준 비교군 컬렉션입니다.
    /// - Returns: 현재 영역보다 작은 가장 가까운 비교군입니다. 없으면 `nil`입니다.
    func previousReferenceArea(
        currentArea: AreaMeter,
        areaCollection: AreaMeterCollection
    ) -> AreaMeter?

    /// 현재 영역 바로 위의 다음 목표 비교군을 계산합니다.
    /// - Parameters:
    ///   - currentArea: 현재 누적 영역 모델입니다.
    ///   - areaCollection: 기본 비교군 컬렉션입니다.
    ///   - featuredGoalAreas: 원격 featured 정책이 반영된 우선 목표 비교군입니다.
    /// - Returns: featured 우선 정책이 반영된 다음 목표 비교군입니다. 없으면 `nil`입니다.
    func nextReferenceArea(
        currentArea: AreaMeter,
        areaCollection: AreaMeterCollection,
        featuredGoalAreas: [AreaMeter]
    ) -> AreaMeter?

    /// 현재 영역을 비교군 리스트 사이에 삽입한 결합 목록을 생성합니다.
    /// - Parameters:
    ///   - currentArea: 현재 누적 영역 모델입니다.
    ///   - areaCollection: 기준 비교군 컬렉션입니다.
    /// - Returns: 현재 영역이 올바른 정렬 위치에 삽입된 비교군 목록입니다.
    func combinedAreas(
        currentArea: AreaMeter,
        areaCollection: AreaMeterCollection
    ) -> [AreaMeter]

    /// 현재 영역 마일스톤을 로컬 저장소에 추가로 저장해야 하는지 판단합니다.
    /// - Parameters:
    ///   - currentArea: 현재 누적 영역 모델입니다.
    ///   - areaCollection: 기준 비교군 컬렉션입니다.
    ///   - persistedAreas: 이미 저장된 최근 마일스톤 목록입니다.
    /// - Returns: 새 마일스톤으로 저장할 가치가 있으면 `true`, 아니면 `false`입니다.
    func shouldPersistCurrentMeter(
        currentArea: AreaMeter,
        areaCollection: AreaMeterCollection,
        persistedAreas: [AreaMeterDTO]
    ) -> Bool

    /// 영역 마일스톤 감지에 사용할 비교군 후보를 계산합니다.
    /// - Parameters:
    ///   - featuredGoalAreas: 원격 featured 목표 목록입니다.
    ///   - fallbackAreas: featured가 비어 있을 때 사용할 기본 비교군 목록입니다.
    /// - Returns: 마일스톤 감지용 후보 목록입니다.
    func milestoneCandidates(
        featuredGoalAreas: [AreaMeter],
        fallbackAreas: [AreaMeter]
    ) -> [AreaMilestoneCandidate]
}

protocol TerritoryWidgetGoalContextServicing {
    /// 선택 반려견/로컬 산책 기록 기준의 위젯 목표 문맥을 계산합니다.
    /// - Parameters:
    ///   - userInfo: 현재 로그인 사용자 정보입니다. 선택 반려견 컨텍스트를 함께 포함합니다.
    ///   - polygons: 로컬에 저장된 전체 산책 다각형 목록입니다.
    ///   - areaReferenceSnapshot: 비교 구역/featured 목표 기준이 담긴 스냅샷입니다.
    /// - Returns: 위젯에서 바로 렌더링할 수 있는 목표 문맥 스냅샷입니다.
    func makeGoalContext(
        userInfo: UserInfo?,
        polygons: [Polygon],
        areaReferenceSnapshot: AreaReferenceSnapshot
    ) -> TerritoryWidgetGoalContextSnapshot
}

struct HomeAreaAggregationService: HomeAreaAggregationServicing {
    /// 선택 반려견/전체 보기 상태를 반영해 홈 화면에 노출할 산책 기록만 필터링합니다.
    /// - Parameters:
    ///   - polygons: 원본 산책 기록 목록입니다.
    ///   - selectedPetId: 현재 선택된 반려견 식별자입니다. 선택되지 않았으면 `nil`입니다.
    ///   - showsAllRecords: 전체 기록 강제 표시 상태입니다.
    /// - Returns: 홈 화면 집계에 사용할 산책 기록 목록입니다.
    func filteredPolygons(
        from polygons: [Polygon],
        selectedPetId: String?,
        showsAllRecords: Bool
    ) -> [Polygon] {
        if showsAllRecords {
            return polygons
        }
        guard let selectedPetId, selectedPetId.isEmpty == false else {
            return polygons
        }

        let taggedPolygons = polygons.filter { ($0.petId?.isEmpty == false) }
        let selectedPetPolygons = polygons.filter { $0.petId == selectedPetId }

        // Legacy records created before session->pet tagging should remain visible.
        if selectedPetPolygons.isEmpty && taggedPolygons.isEmpty {
            return polygons
        }
        return selectedPetPolygons
    }

    /// 홈 화면 현재 영역 모델을 생성합니다.
    /// - Parameters:
    ///   - totalArea: 현재 누적 산책 영역(`m²`)입니다.
    ///   - selectedPetNameWithYi: 조사 보정이 적용된 반려견 이름입니다.
    /// - Returns: 홈 화면 현재 영역 카드에 표시할 `AreaMeter`입니다.
    func makeCurrentArea(totalArea: Double, selectedPetNameWithYi: String) -> AreaMeter {
        AreaMeter("\(selectedPetNameWithYi)의 영역", totalArea)
    }

    /// 현재 영역 바로 아래의 비교군을 계산합니다.
    /// - Parameters:
    ///   - currentArea: 현재 누적 영역 모델입니다.
    ///   - areaCollection: 기준 비교군 컬렉션입니다.
    /// - Returns: 현재 영역보다 작은 가장 가까운 비교군입니다. 없으면 `nil`입니다.
    func previousReferenceArea(
        currentArea: AreaMeter,
        areaCollection: AreaMeterCollection
    ) -> AreaMeter? {
        areaCollection.nearistArea(of: currentArea.area)
    }

    /// 현재 영역 바로 위의 다음 목표 비교군을 계산합니다.
    /// - Parameters:
    ///   - currentArea: 현재 누적 영역 모델입니다.
    ///   - areaCollection: 기본 비교군 컬렉션입니다.
    ///   - featuredGoalAreas: 원격 featured 정책이 반영된 우선 목표 비교군입니다.
    /// - Returns: featured 우선 정책이 반영된 다음 목표 비교군입니다. 없으면 `nil`입니다.
    func nextReferenceArea(
        currentArea: AreaMeter,
        areaCollection: AreaMeterCollection,
        featuredGoalAreas: [AreaMeter]
    ) -> AreaMeter? {
        let featuredNext = featuredGoalAreas.first(where: { $0.area > currentArea.area })
        let defaultNext = areaCollection.closeArea(of: currentArea.area)
        if let featuredNext, let defaultNext {
            return featuredNext.area <= defaultNext.area ? featuredNext : defaultNext
        }
        return featuredNext ?? defaultNext
    }

    /// 현재 영역을 비교군 리스트 사이에 삽입한 결합 목록을 생성합니다.
    /// - Parameters:
    ///   - currentArea: 현재 누적 영역 모델입니다.
    ///   - areaCollection: 기준 비교군 컬렉션입니다.
    /// - Returns: 현재 영역이 올바른 정렬 위치에 삽입된 비교군 목록입니다.
    func combinedAreas(
        currentArea: AreaMeter,
        areaCollection: AreaMeterCollection
    ) -> [AreaMeter] {
        let insertionIndex = areaCollection.areas.firstIndex(where: { $0.area > currentArea.area }) ?? areaCollection.areas.count
        var areas = areaCollection.areas
        areas.insert(currentArea, at: insertionIndex)
        return areas
    }

    /// 현재 영역 마일스톤을 로컬 저장소에 추가로 저장해야 하는지 판단합니다.
    /// - Parameters:
    ///   - currentArea: 현재 누적 영역 모델입니다.
    ///   - areaCollection: 기준 비교군 컬렉션입니다.
    ///   - persistedAreas: 이미 저장된 최근 마일스톤 목록입니다.
    /// - Returns: 새 마일스톤으로 저장할 가치가 있으면 `true`, 아니면 `false`입니다.
    func shouldPersistCurrentMeter(
        currentArea: AreaMeter,
        areaCollection: AreaMeterCollection,
        persistedAreas: [AreaMeterDTO]
    ) -> Bool {
        guard let previousReference = previousReferenceArea(currentArea: currentArea, areaCollection: areaCollection) else {
            return false
        }
        guard let lastPersisted = persistedAreas.last else {
            return true
        }
        if lastPersisted.area == previousReference.area && lastPersisted.areaName == previousReference.areaName {
            return false
        }
        if lastPersisted.area > previousReference.area {
            return false
        }
        return true
    }

    /// 영역 마일스톤 감지에 사용할 비교군 후보를 계산합니다.
    /// - Parameters:
    ///   - featuredGoalAreas: 원격 featured 목표 목록입니다.
    ///   - fallbackAreas: featured가 비어 있을 때 사용할 기본 비교군 목록입니다.
    /// - Returns: 마일스톤 감지용 후보 목록입니다.
    func milestoneCandidates(
        featuredGoalAreas: [AreaMeter],
        fallbackAreas: [AreaMeter]
    ) -> [AreaMilestoneCandidate] {
        let sourceAreas = featuredGoalAreas.isEmpty ? Array(fallbackAreas.suffix(10)) : featuredGoalAreas
        return sourceAreas.map { area in
            AreaMilestoneCandidate(
                landmarkName: area.areaName,
                thresholdArea: area.area
            )
        }
    }
}

struct TerritoryWidgetGoalContextService: TerritoryWidgetGoalContextServicing {
    private let areaAggregationService: HomeAreaAggregationServicing

    /// 영역 위젯 목표 문맥 서비스를 생성합니다.
    /// - Parameter areaAggregationService: 홈 목표 계산과 동일한 비교군/면적 집계 규칙을 제공하는 서비스입니다.
    init(areaAggregationService: HomeAreaAggregationServicing = HomeAreaAggregationService()) {
        self.areaAggregationService = areaAggregationService
    }

    /// 선택 반려견/로컬 산책 기록 기준의 위젯 목표 문맥을 계산합니다.
    /// - Parameters:
    ///   - userInfo: 현재 로그인 사용자 정보입니다. 선택 반려견 컨텍스트를 함께 포함합니다.
    ///   - polygons: 로컬에 저장된 전체 산책 다각형 목록입니다.
    ///   - areaReferenceSnapshot: 비교 구역/featured 목표 기준이 담긴 스냅샷입니다.
    /// - Returns: 위젯에서 바로 렌더링할 수 있는 목표 문맥 스냅샷입니다.
    func makeGoalContext(
        userInfo: UserInfo?,
        polygons: [Polygon],
        areaReferenceSnapshot: AreaReferenceSnapshot
    ) -> TerritoryWidgetGoalContextSnapshot {
        let selectedPet = userInfo?.selectedPet
        let contextLabel = makeContextLabel(selectedPetName: selectedPet?.petName)

        guard areaReferenceSnapshot.allAreas.isEmpty == false else {
            return TerritoryWidgetGoalContextSnapshot(
                status: .unavailable,
                contextLabel: contextLabel,
                nextGoalName: nil,
                nextGoalAreaM2: nil,
                remainingAreaM2: nil,
                progressRatio: nil,
                message: "앱을 열어 비교 구역을 다시 불러오면 다음 목표를 계산해드릴게요."
            )
        }

        let filteredPolygons = areaAggregationService.filteredPolygons(
            from: polygons,
            selectedPetId: selectedPet?.petId,
            showsAllRecords: false
        )

        guard filteredPolygons.isEmpty == false else {
            return TerritoryWidgetGoalContextSnapshot(
                status: .emptyData,
                contextLabel: contextLabel,
                nextGoalName: nil,
                nextGoalAreaM2: nil,
                remainingAreaM2: nil,
                progressRatio: nil,
                message: "첫 산책을 시작하면 다음 목표와 남은 면적을 바로 보여드릴게요."
            )
        }

        let totalArea = filteredPolygons.map(\.walkingArea).reduce(0.0, +)
        let selectedPetNameWithYi = (selectedPet?.petName ?? "강아지").addYi()
        let currentArea = areaAggregationService.makeCurrentArea(
            totalArea: totalArea,
            selectedPetNameWithYi: selectedPetNameWithYi
        )
        let featuredGoalAreas = areaReferenceSnapshot.featuredAreas.sorted { $0.area < $1.area }
        let areaCollection = AreaMeterCollection(areas: areaReferenceSnapshot.allAreas)

        guard let nextGoal = areaAggregationService.nextReferenceArea(
            currentArea: currentArea,
            areaCollection: areaCollection,
            featuredGoalAreas: featuredGoalAreas
        ) else {
            return TerritoryWidgetGoalContextSnapshot(
                status: .completed,
                contextLabel: contextLabel,
                nextGoalName: nil,
                nextGoalAreaM2: nil,
                remainingAreaM2: nil,
                progressRatio: 1.0,
                message: "준비된 비교 구역을 모두 달성했어요. 앱에서 새 기준을 확인해보세요."
            )
        }

        let remainingArea = max(0, nextGoal.area - currentArea.area)
        let progressRatio = min(1.0, max(0.0, currentArea.area / nextGoal.area))
        return TerritoryWidgetGoalContextSnapshot(
            status: .ready,
            contextLabel: contextLabel,
            nextGoalName: nextGoal.areaName,
            nextGoalAreaM2: nextGoal.area,
            remainingAreaM2: remainingArea,
            progressRatio: progressRatio,
            message: "\(nextGoal.areaName)까지 \(remainingArea.calculatedAreaString) 남았어요."
        )
    }

    /// 위젯 목표 카드 상단에 표시할 선택 반려견 문맥 라벨을 생성합니다.
    /// - Parameter selectedPetName: 현재 선택 반려견 이름입니다.
    /// - Returns: 위젯 목표 문맥을 설명하는 짧은 라벨 문자열입니다.
    private func makeContextLabel(selectedPetName: String?) -> String {
        guard let selectedPetName, selectedPetName.isEmpty == false else {
            return "현재 기록 기준"
        }
        return "선택 반려견 · \(selectedPetName)"
    }
}
