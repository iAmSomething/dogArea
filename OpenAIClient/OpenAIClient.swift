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
public struct OpenAIClient{
    let client: Client
    public init(apikey: String) {
        self.client = Client(serverURL: try! Servers.server1(),
                             transport: URLSessionTransport(),
                             middlewares: [AuthMiddleware(apiKey: apikey)])
        
    }
    public func generateImage(prompt: String) async throws -> URL {
        let input = Operations.createImage.Input(body: .json(
            .init(n: 1,
                prompt: prompt,
                  response_format: .url,
                  size: ._1024x1024)))

        let response = try await client.createImage(input)
        
        switch response {
            
        case .ok(let response):
            switch response.body {
            case .json(let imageResponse) where imageResponse.data.first?.url != nil:
                return URL(string: imageResponse.data.first!.url!)!
                
            default :
                throw "Unknown response"
            }
        case .undocumented(statusCode: let statusCode, _):
            throw "\(statusCode) : Failed to load image"
        }
    }
}
extension String: LocalizedError {
    public var errorDescription: String? { self }
}
