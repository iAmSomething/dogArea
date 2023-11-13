//
//  MapCapture.swift
//  dogArea
//
//  Created by 김태훈 on 11/13/23.
//

import Combine
import MapKit
import SwiftUI
class MapImageProvider: ObservableObject {
    private var cancellables: Set<AnyCancellable> = []

    @Published var capturedImage: UIImage?

    func captureMapImage(for polygon: MKPolygon) {
        captureMapImage(for: polygon)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] comp in
                switch comp {
                case .failure(let error):
                    print(error.localizedDescription)
                    self?.capturedImage = nil
                case .finished:
                    break
                }
            }, receiveValue: { [weak self] image in
                self?.capturedImage = image
            })
            .store(in: &cancellables)
    }

    private func captureMapImage(for polygon: MKPolygon) -> Future<UIImage?, Error> {
        return Future { promise in
            print(polygon.coordinate)
            let mapView = MKMapView()
            mapView.camera.centerCoordinate = polygon.coordinate

            let options = MKMapSnapshotter.Options()
            mapView.setVisibleMapRect(polygon.boundingMapRect, edgePadding: UIEdgeInsets(top: 200, left: 200, bottom: 200, right: 200), animated: false)
            mapView.setCameraBoundary(.init(mapRect: polygon.boundingMapRect), animated: false)

            let optionSize = max(polygon.boundingMapRect.width, polygon.boundingMapRect.height)
            let padding: Double = 100.0
            let polygonRect = polygon.boundingMapRect
            let center = MKMapPoint(x: polygonRect.midX, y: polygonRect.midY)
            let paddedRect = MKMapRect(x: center.x - optionSize/2 - padding, y: center.y - optionSize/2 - padding, width: optionSize + padding*2, height: optionSize + padding*2)
            options.mapRect = paddedRect

            if mapView.frame.size == CGSize(width: 0, height: 0) {
                options.size = CGSize(width: 400, height: 400)
            } else {
                options.size = mapView.frame.size
            }

            let snapshotter = MKMapSnapshotter(options: options)
            snapshotter.start(with: .main) { snapshot, error in
                if let error = error {
                    print(error.localizedDescription)
                    promise(.failure(error))
                } else if let snapshot = snapshot {
                    let snapshotImage = snapshot.image
                    UIGraphicsBeginImageContextWithOptions(snapshotImage.size, true, snapshotImage.scale)
                    snapshotImage.draw(at: .zero)

                    let context = UIGraphicsGetCurrentContext()!

                    let pointCount = polygon.pointCount
                    let points = polygon.points()
                    context.setFillColor(UIColor.appYelloww.withAlphaComponent(0.3).cgColor)
                    context.setStrokeColor(UIColor.appYelloww.cgColor)
                    context.setLineWidth(0.5)

                    for i in 0..<pointCount {
                        let point = points[i]
                        let coordinate = point.coordinate
                        let location = snapshot.point(for: coordinate)
                        if i == 0 {
                            context.move(to: location)
                        } else {
                            context.addLine(to: location)
                        }
                    }

                    context.closePath()
                    context.fillPath()
                    context.strokePath()

                    let drawnImage = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()
                    promise(.success(drawnImage))
                }
            }
        }
    }
}

