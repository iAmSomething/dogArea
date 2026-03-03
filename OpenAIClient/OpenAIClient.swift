//
//  OpenAIClient.swift
//  OpenAIClient
//
//  Created by 김태훈 on 10/17/23.
//

import Foundation
import OpenAPIRuntime
import OpenAPIURLSession
import HTTPTypes
struct AuthMiddleware: ClientMiddleware {
    let apiKey: String
    
    func intercept(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String, next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields.append(.init(name: .authorization, value: "Bearer \(apiKey)"))
        return try await next(request,body,baseURL)
    }
}
enum OpenAIClientError: LocalizedError {
    case missingImageURL
    case http(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .missingImageURL:
            return "Missing image URL in response"
        case .http(let statusCode):
            return "\(statusCode) : Failed to load image"
        }
    }
}
public struct OpenAIClient{
    let client: Client
    public init(apikey: String) {
        let serverURL: URL
        do {
            serverURL = try Servers.server1()
        } catch {
            serverURL = URL(string: "https://api.openai.com/v1") ?? URL(fileURLWithPath: "/")
        }
        self.client = Client(serverURL: serverURL,
                             transport: URLSessionTransport(),
                             middlewares: [AuthMiddleware(apiKey: apikey)])
        
    }
    public func generateImage(prompt: String) async throws -> URL {
        let input = Operations.createImage.Input(body: .json(
            .init(prompt: prompt,
                  n: 1,
                  response_format: .url,
                  size: ._1024x1024)))

        let response = try await client.createImage(input)
        
        switch response {
            
        case .ok(let response):
            switch response.body {
            case .json(let imageResponse):
                guard
                    let urlString = imageResponse.data.first?.url,
                    let generatedURL = URL(string: urlString)
                else {
                    throw OpenAIClientError.missingImageURL
                }
                return generatedURL
            }
        case .undocumented(statusCode: let statusCode, _):
            throw OpenAIClientError.http(statusCode: statusCode)
        }
    }
}
