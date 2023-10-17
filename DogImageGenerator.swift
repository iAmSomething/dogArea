//
//  DogImageGenerator.swift
//  dogArea
//
//  Created by 김태훈 on 10/16/23.
//

import Foundation
import Vision
import SwiftUI
import UIKit
import CoreImage
class ImageViewer{
    let completionHandler: VNRequestCompletionHandler? = nil
    let ciimage: CIImage = CIImage()

    func coreMLCompletionHandler(request:VNRequest?, error: Error?) {
        lazy var coreMLRequest: VNCoreMLRequest = {
            let model: VNCoreMLModel = try! VNCoreMLModel(for: gan(configuration: MLModelConfiguration()).model)
            let request: VNCoreMLRequest = .init(model: model, completionHandler: self.completionHandler)
            return request
        }()
        let handler = VNImageRequestHandler(ciImage: ciimage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            do {
                try handler.perform([])
            } catch let error {
                print(error)
            }
        }
        let result = coreMLRequest.results?.first as! VNCoreMLFeatureValueObservation
        let multiArray = result.featureValue.multiArrayValue
        //let cgimage = multiArray?.cgImage（min：-1,max：1,channel：nil）
    }

}
class ganInput: MLFeatureProvider {
    var style: MLMultiArray
    var featureNames: Set<String> {
        get {
            ["style"]
        }
    }
    init(style: MLMultiArray) {
        self.style = style
    }
    func featureValue(for featureName: String) -> MLFeatureValue? {
        if (featureName == "style") {
            return MLFeatureValue(multiArray: style)
        }
        return nil
    }
    convenience init (style: MLShapedArray<Float>) {
        self.init(style: MLMultiArray(style))
    }
}
class ganOutput: MLFeatureProvider {
    private let provider: MLFeatureProvider
    
    lazy var activationOut: CVPixelBuffer = {
        [unowned self] in return self.provider.featureValue(for: "activation_out")!.imageBufferValue
    }()!
    var featureNames: Set<String> {
        return self.provider.featureNames
    }
    func featureValue(for featureName: String) -> MLFeatureValue? {
        return self.provider.featureValue(for: featureName)
    }
    init(provider: MLFeatureProvider) {
        self.provider = provider
    }
    init(activationOut: CVPixelBuffer) {
        self.provider = try! MLDictionaryFeatureProvider(dictionary: ["activation_out" : MLFeatureValue(pixelBuffer: activationOut)])
    }
}
class gan {
    let model: MLModel
    class var urlOfModelInThisBundle : URL {
        let bundle = Bundle(for: self)
        return bundle.url(forResource: "synthesisNetwork", withExtension:"mlmodelc")!
    }
    init(model: MLModel) {
        self.model = model
    }
    convenience init(configuration: MLModelConfiguration) throws {
        try self.init(contentsOf: type(of:self).urlOfModelInThisBundle, configuration: configuration)
    }
    convenience init(contentsOf modelURL: URL) throws {
        try self.init(model: MLModel(contentsOf: modelURL))
    }
    convenience init(contentsOf modelURL: URL, configuration: MLModelConfiguration) throws {
        try self.init(model: MLModel(contentsOf: modelURL, configuration: configuration))
    }
    
    class func load(configuration: MLModelConfiguration = MLModelConfiguration(),
                    completionHandler handler : @escaping (Swift.Result<gan, Error>) -> Void) {
        self.load(contentsOf: urlOfModelInThisBundle, configuration: configuration, completionHandler: handler)
    }
    class func load(configuration: MLModelConfiguration = MLModelConfiguration()) async throws -> gan {
        return try await self.load(contentsOf: self.urlOfModelInThisBundle, configuration: configuration)
    }
    class func load(contentsOf modelURL: URL, configuration: MLModelConfiguration = MLModelConfiguration(),
                    completionHandler handler : @escaping (Swift.Result<gan, Error>) -> Void) {
        MLModel.load(contentsOf: modelURL, configuration: configuration) { res in
            switch res {
            case .success(let model) :
                handler(.success(gan(model: model)))
            case .failure(let error) :
                handler(.failure(error))
                
            }
        }
    }    
    class func load(contentsOf modelURL: URL, configuration: MLModelConfiguration = MLModelConfiguration()) async throws -> gan {
        let model = try await MLModel.load(contentsOf: modelURL, configuration: configuration)
        return gan(model: model)
    }
}
