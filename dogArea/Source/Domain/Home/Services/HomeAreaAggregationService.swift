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
