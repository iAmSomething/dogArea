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
    private var cancellables: Set<AnyCancellable> = []

    var pets: [PetInfo] {
        userInfo?.pet ?? []
    }

    init() {
        bindSelectedPetSync()
        reloadSelectedPetContext()
    }

    func fetchModel() {
        self.walkingDatas = self.fetchPolygons().map{
            .init(polygon: $0)
        }
        reloadSelectedPetContext()
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
    }

    private func bindSelectedPetSync() {
        NotificationCenter.default.publisher(for: UserdefaultSetting.selectedPetDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadSelectedPetContext()
            }
            .store(in: &cancellables)
    }
}
