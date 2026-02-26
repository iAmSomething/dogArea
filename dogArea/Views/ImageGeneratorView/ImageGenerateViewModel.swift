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
final class ImageGenerateViewModel {
    var prompt = ""
    var fetchPhase = FetchPhase.initial

    private let generator: any ImageGenerating
    let providerName: String

    init() {
        let configuration = ImageGenerationConfiguration.load()
        self.providerName = configuration.provider.rawValue
        self.generator = configuration.makeGenerator()
    }

    @MainActor
    func generateImage() async {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            fetchPhase = .failure("프롬프트를 입력해주세요.")
            return
        }

        fetchPhase = .loading
        do {
            let data = try await generator.generateImageData(prompt: trimmedPrompt)
            guard let image = UIImage(data: data) else {
                fetchPhase = .failure("이미지 디코딩에 실패했습니다.")
                return
            }
            fetchPhase = .success(.init(uiImage: image))
        } catch {
            fetchPhase = .failure(error.localizedDescription)
        }
    }
}

enum FetchPhase: Equatable {
    case initial
    case loading
    case success(Image)
    case failure(String)
}

private protocol ImageGenerating {
    func generateImageData(prompt: String) async throws -> Data
}

private struct ImageGenerationConfiguration {
    enum Provider: String {
        case openAI = "openai"
        case gemini = "gemini"
        case proxy = "proxy"
    }

    let provider: Provider
    let openAIAPIKey: String?
    let proxyURL: URL?

    static func load(from bundle: Bundle = .main) -> ImageGenerationConfiguration {
        let providerRaw = bundle.stringValue(forInfoDictionaryKey: "IMAGE_PROVIDER")?.lowercased() ?? "openai"
        let provider = Provider(rawValue: providerRaw) ?? .openAI
        let openAIAPIKey = bundle.stringValue(forInfoDictionaryKey: "OpenAI")
        let proxyURL = bundle.stringValue(forInfoDictionaryKey: "IMAGE_PROXY_URL").flatMap(URL.init(string:))

        return .init(
            provider: provider,
            openAIAPIKey: openAIAPIKey,
            proxyURL: proxyURL
        )
    }

    func makeGenerator() -> any ImageGenerating {
        switch provider {
        case .openAI:
            if let openAIAPIKey, !openAIAPIKey.isEmpty {
                return OpenAIImageGenerator(apiKey: openAIAPIKey)
            }
            if let proxyURL {
                return ProxyImageGenerator(endpoint: proxyURL, providerHint: "openai")
            }
            return FailingImageGenerator(message: "OpenAI API Key 또는 IMAGE_PROXY_URL이 필요합니다.")
        case .gemini:
            if let proxyURL {
                return ProxyImageGenerator(endpoint: proxyURL, providerHint: "gemini")
            }
            return FailingImageGenerator(message: "Gemini provider는 IMAGE_PROXY_URL 백엔드 라우팅이 필요합니다.")
        case .proxy:
            if let proxyURL {
                return ProxyImageGenerator(endpoint: proxyURL, providerHint: nil)
            }
            return FailingImageGenerator(message: "IMAGE_PROXY_URL이 비어있습니다.")
        }
    }
}

private struct OpenAIImageGenerator: ImageGenerating {
    let client: OpenAIClient

    init(apiKey: String) {
        self.client = .init(apikey: apiKey)
    }

    func generateImageData(prompt: String) async throws -> Data {
        let url = try await client.generateImage(prompt: prompt)
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }
}

private struct ProxyImageGenerator: ImageGenerating {
    let endpoint: URL
    let providerHint: String?

    func generateImageData(prompt: String) async throws -> Data {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var requestPayload: [String: String] = ["prompt": prompt]
        if let providerHint {
            requestPayload["provider"] = providerHint
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: requestPayload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImageGenerationError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let serverMessage = String(data: data, encoding: .utf8) ?? "proxy server error"
            throw ImageGenerationError.server(message: serverMessage)
        }
        let responsePayload = try JSONDecoder().decode(ProxyImageResponse.self, from: data)

        if let base64 = responsePayload.imageBase64 ?? responsePayload.b64JSON {
            if let decoded = Data(base64Encoded: base64) {
                return decoded
            }
            throw ImageGenerationError.invalidResponse
        }
        if let imageURLString = responsePayload.imageURL, let imageURL = URL(string: imageURLString) {
            let (imageData, _) = try await URLSession.shared.data(from: imageURL)
            return imageData
        }
        throw ImageGenerationError.invalidResponse
    }
}

private struct ProxyImageResponse: Decodable {
    let imageURL: String?
    let imageBase64: String?
    let b64JSON: String?

    enum CodingKeys: String, CodingKey {
        case imageURL = "image_url"
        case imageBase64 = "image_base64"
        case b64JSON = "b64_json"
    }
}

private struct FailingImageGenerator: ImageGenerating {
    let message: String

    func generateImageData(prompt: String) async throws -> Data {
        throw ImageGenerationError.server(message: message)
    }
}

private enum ImageGenerationError: LocalizedError {
    case invalidResponse
    case server(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "이미지 생성 응답 형식이 올바르지 않습니다."
        case .server(let message):
            return message
        }
    }
}

private extension Bundle {
    func stringValue(forInfoDictionaryKey key: String) -> String? {
        guard let value = object(forInfoDictionaryKey: key) as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("$("), trimmed.hasSuffix(")") {
            return nil
        }
        return trimmed
    }
}
