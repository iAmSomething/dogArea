//
//  WalkListViewModel.swift
//  dogArea
//
//  Created by 김태훈 on 11/8/23.
//

import Foundation
import Combine
final class WalkListViewModel: ObservableObject {
    @Published var walkingDatas: [WalkDataModel] = []
    @Published var userInfo: UserInfo? = nil
    @Published var selectedPetId: String = ""
    @Published var selectedPetName: String = "강아지"
    @Published private(set) var isShowingAllRecordsOverride: Bool = false
    private var allWalkingDatas: [WalkDataModel] = []
    private var cancellables: Set<AnyCancellable> = []
    private let walkRepository: WalkRepositoryProtocol

    var pets: [PetInfo] {
        userInfo?.pet.filter(\.isActive) ?? []
    }

    var shouldShowSelectedPetEmptyState: Bool {
        guard isShowingAllRecordsOverride == false else { return false }
        guard selectedPetId.isEmpty == false else { return false }
        guard allWalkingDatas.isEmpty == false else { return false }
        let tagged = allWalkingDatas.filter { ($0.petId?.isEmpty == false) }
        guard tagged.isEmpty == false else { return false }
        let selected = tagged.filter { $0.petId == selectedPetId }
        return selected.isEmpty
    }

    init(walkRepository: WalkRepositoryProtocol = WalkRepositoryContainer.shared) {
        self.walkRepository = walkRepository
        bindSelectedPetSync()
        reloadSelectedPetContext()
    }

    func fetchModel() {
        self.allWalkingDatas = self.walkRepository.fetchPolygons().map{
            .init(polygon: $0)
        }
        reloadSelectedPetContext()
        applySelectedPetFilter()
    }

    func selectPet(_ petId: String) {
        guard pets.contains(where: { $0.petId == petId }) else { return }
        isShowingAllRecordsOverride = false
        UserdefaultSetting.shared.setSelectedPetId(petId, source: "walk_list")
    }

    func showAllRecordsTemporarily() {
        guard allWalkingDatas.isEmpty == false else { return }
        isShowingAllRecordsOverride = true
        applySelectedPetFilter()
    }

    func showSelectedPetRecords() {
        isShowingAllRecordsOverride = false
        applySelectedPetFilter()
    }

    private func reloadSelectedPetContext() {
        userInfo = UserdefaultSetting.shared.getValue()
        let selected = UserdefaultSetting.shared.selectedPet(from: userInfo)
        selectedPetId = selected?.petId ?? ""
        selectedPetName = selected?.petName ?? "강아지"
        applySelectedPetFilter()
    }

    private func bindSelectedPetSync() {
        NotificationCenter.default.publisher(for: UserdefaultSetting.selectedPetDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isShowingAllRecordsOverride = false
                self?.reloadSelectedPetContext()
            }
            .store(in: &cancellables)
    }

    private func applySelectedPetFilter() {
        if isShowingAllRecordsOverride {
            walkingDatas = allWalkingDatas
            return
        }
        guard selectedPetId.isEmpty == false else {
            walkingDatas = allWalkingDatas
            return
        }

        let tagged = allWalkingDatas.filter { ($0.petId?.isEmpty == false) }
        let selected = allWalkingDatas.filter { $0.petId == selectedPetId }
        if selected.isEmpty && tagged.isEmpty {
            walkingDatas = allWalkingDatas
            return
        }
        walkingDatas = selected
    }
}
