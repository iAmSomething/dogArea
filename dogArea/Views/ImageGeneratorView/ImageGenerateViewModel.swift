//
//  ImageGenerateViewModel.swift
//  dogArea
//
//  Created by 김태훈 on 10/17/23.
//

import Foundation
import SwiftUI
import Observation
#if canImport(UIKit)
import UIKit
#endif

@Observable
final class ImageGenerateViewModel {
    struct GenerationContext: Equatable {
        let userId: String
        let petId: String
        let petName: String
        let sourceImageURL: String
    }

    var fetchPhase = FetchPhase.initial
    var selectedPetName: String = "강아지"
    var lastFailureMessage: String = ""

    private let client = CaricatureEdgeClient()
    private let metricTracker = AppMetricTracker.shared
    private var lastContext: GenerationContext?

    func reloadSelectedPetContext() {
        guard let user = UserdefaultSetting.shared.getValue(),
              let pet = UserdefaultSetting.shared.selectedPet(from: user) else {
            selectedPetName = "강아지"
            return
        }
        selectedPetName = pet.petName
    }

    @MainActor
    func generateImage() async {
        guard AppFeatureGate.isAllowed(.aiGeneration, session: AppFeatureGate.currentSession()) else {
            fetchPhase = .failure("회원 전용 기능입니다. 로그인 후 다시 시도해주세요.")
            return
        }

        guard let context = resolveContext() else {
            fetchPhase = .failure("선택된 반려견 이미지가 없어 캐리커처를 생성할 수 없습니다.")
            return
        }

        await generateImage(using: context)
    }

    @MainActor
    func retryLastRequest() async {
        guard let lastContext else {
            fetchPhase = .failure("재시도할 요청이 없습니다. 먼저 캐리커처를 생성해주세요.")
            return
        }
        await generateImage(using: lastContext)
    }

    private func resolveContext() -> GenerationContext? {
        guard let user = UserdefaultSetting.shared.getValue(),
              let pet = UserdefaultSetting.shared.selectedPet(from: user),
              let sourceImageURL = pet.petProfile ?? pet.caricatureURL,
              sourceImageURL.isEmpty == false else {
            return nil
        }

        return GenerationContext(
            userId: user.id,
            petId: pet.petId,
            petName: pet.petName,
            sourceImageURL: sourceImageURL
        )
    }

    @MainActor
    private func generateImage(using context: GenerationContext) async {
        selectedPetName = context.petName
        lastContext = context
        fetchPhase = .loading
        lastFailureMessage = ""
        UserdefaultSetting.shared.updateFirstPetCaricature(status: .processing)

        do {
            let response = try await client.requestCaricature(
                petId: context.petId,
                userId: context.userId,
                sourceImageURL: context.sourceImageURL,
                requestId: UUID().uuidString.lowercased()
            )
            guard let caricatureURL = response.caricatureURL,
                  let url = URL(string: caricatureURL) else {
                throw CaricatureEdgeClient.RequestError.invalidResponse
            }
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else {
                throw CaricatureEdgeClient.RequestError.invalidResponse
            }

            UserdefaultSetting.shared.updateFirstPetCaricature(
                status: .ready,
                caricatureURL: caricatureURL,
                provider: response.provider
            )
            metricTracker.track(
                .caricatureSuccess,
                userKey: context.userId,
                featureKey: .caricatureAsyncV1,
                payload: ["provider": response.provider ?? "unknown"]
            )
            fetchPhase = .success(.init(uiImage: image))
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            lastFailureMessage = message
            fetchPhase = .failure(message)
            UserdefaultSetting.shared.updateFirstPetCaricature(status: .failed)
            metricTracker.track(
                .caricatureFailed,
                userKey: context.userId,
                featureKey: .caricatureAsyncV1,
                payload: ["error": message]
            )
        }
    }
}

enum FetchPhase: Equatable {
    case initial
    case loading
    case success(Image)
    case failure(String)
}
