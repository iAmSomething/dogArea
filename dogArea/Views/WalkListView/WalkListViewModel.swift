//
//  WalkListViewModel.swift
//  dogArea
//
//  Created by 김태훈 on 11/8/23.
//

import Foundation
import Combine
final class WalkListViewModel: ObservableObject, CoreDataProtocol {
    @Published var walkingDatas: [WalkDataModel] = []
    @Published var userInfo: UserInfo? = nil
    @Published var selectedPetId: String = ""
    @Published var selectedPetName: String = "강아지"
    private var allWalkingDatas: [WalkDataModel] = []
    private let sessionMetadataStore = WalkSessionMetadataStore.shared
    private var cancellables: Set<AnyCancellable> = []

    var pets: [PetInfo] {
        userInfo?.pet ?? []
    }

    init() {
        bindSelectedPetSync()
        reloadSelectedPetContext()
    }

    func fetchModel() {
        self.allWalkingDatas = self.fetchPolygons().map{
            .init(polygon: $0)
        }
        reloadSelectedPetContext()
        applySelectedPetFilter()
    }

    func selectPet(_ petId: String) {
        guard pets.contains(where: { $0.petId == petId }) else { return }
        UserdefaultSetting.shared.setSelectedPetId(petId, source: "walk_list")
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
                self?.reloadSelectedPetContext()
            }
            .store(in: &cancellables)
    }

    private func applySelectedPetFilter() {
        guard selectedPetId.isEmpty == false else {
            walkingDatas = allWalkingDatas
            return
        }

        let tagged = allWalkingDatas.filter { sessionMetadataStore.petId(sessionId: $0.id) != nil }
        let selected = allWalkingDatas.filter { sessionMetadataStore.petId(sessionId: $0.id) == selectedPetId }
        if selected.isEmpty && tagged.isEmpty {
            walkingDatas = allWalkingDatas
            return
        }
        walkingDatas = selected
    }
}
