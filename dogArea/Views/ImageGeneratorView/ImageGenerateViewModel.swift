//
//  ImageGenerateViewModel.swift
//  OpenAIClient
//
//  Created by 김태훈 on 10/17/23.
//

import Foundation
import SwiftUI
import Observation
import OpenAIClient

@Observable
class ImageGenerateViewModel {
  let client: OpenAIClient
  var prompt = ""
  var fetchPhase = FetchPhase.initial
//  init(apiKey: String) {
//    self.client = .init(apikey: apiKey)
//  }
  init() {
    let apiKey = Bundle.main.object(forInfoDictionaryKey: "OpenAI") as? String ?? ""
    self.client = .init(apikey: apiKey)
  }
  @MainActor
  func generateImage() async {
    self.fetchPhase = .loading
    do {
      let url = try await client.generateImage(prompt: prompt)
      let (data, _) = try await URLSession.shared.data(from: url)
      guard let image = UIImage(data: data) else {
        self.fetchPhase = .failure("failed to load image")
        return
      }
      self.fetchPhase = .success(.init(uiImage: image))
    } catch {
      self.fetchPhase = .failure(error.localizedDescription)
    }
  }
}
enum FetchPhase: Equatable {
  case initial
  case loading
  case success(Image)
  case failure(String)
}
