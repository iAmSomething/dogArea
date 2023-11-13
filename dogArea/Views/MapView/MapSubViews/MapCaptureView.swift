import SwiftUI
import MapKit
struct MapCaptureView: UIViewRepresentable {
    @Binding var captureImage: UIImage?
    let polygon: Polygon
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.camera.centerCoordinate = polygon.polygon!.coordinate
        mapView.addOverlay(polygon.polygon!)
        captureMapSnapshot(from: mapView) { image in
            DispatchQueue.main.async {
                captureImage = image
            }
        }
        return MKMapView()
    }
    func updateUIView(_ uiView: MKMapView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polygonOverlay = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygonOverlay)
                renderer.fillColor = UIColor.red.withAlphaComponent(0.3)
                renderer.strokeColor = UIColor.red
                renderer.lineWidth = 0.5
                return renderer
            }
            return MKOverlayRenderer()
        }
    }
    
    private func captureMapSnapshot(from mapView: MKMapView, completion: @escaping (UIImage?) -> Void) {
        let options = MKMapSnapshotter.Options()
        guard let polygon = polygon.polygon else {return}
        mapView.setVisibleMapRect(polygon.boundingMapRect, edgePadding: UIEdgeInsets(top: 200, left: 200, bottom: 200, right: 200), animated: false)
        mapView.setCameraBoundary(.init(mapRect: polygon.boundingMapRect), animated: false)
        let mapSize = polygon.boundingMapRect.width > polygon.boundingMapRect.height ? polygon.boundingMapRect.width : polygon.boundingMapRect.height
//        options.mapRect = .init(origin: .init(x: polygon.boundingMapRect.origin, y: polygon.boundingMapRect.origin.y) , size: .init(width: polygon.boundingMapRect.width, height: polygon.boundingMapRect.height))
        let optionSize = polygon.boundingMapRect.width > polygon.boundingMapRect.height ? polygon.boundingMapRect.width : polygon.boundingMapRect.height
        let padding: Double = 100.0 // 여유 공간 크기
        let polygonRect = polygon.boundingMapRect
        let center = MKMapPoint(x: polygonRect.midX, y: polygonRect.midY)
        let paddedRect = MKMapRect(x: center.x - optionSize/2 - padding, y: center.y - optionSize/2 - padding, width: optionSize + padding*2, height: optionSize + padding*2)
        options.mapRect = paddedRect
        if mapView.frame.size == CGSize(width: 0, height: 0) {
            options.size = CGSize(width: 400,
                                  height: 400)
        } else {
            options.size = mapView.frame.size
        }
        
        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start(with: .main) { snapshot, error in
            guard let snapshot = snapshot, error == nil else {
                completion(nil)
                return
            }
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
            completion(drawnImage)

//            print("스냅샷 이미지 사진 크기")
//            print(snapshot.image.size)
//            print("스냅샷이 보는 지도 중심")
//            print(options.camera.centerCoordinate)
//            print("스냅샷이 보는 지도 거리 (미터)")
//            print(options.camera.centerCoordinateDistance)
//
//            print("폴리곤 렌더러의 바운딩박스")
//            print(polygonRenderer.path.boundingBox)
//            print("스냅샷이 보는 지도 리전")
//            print(options.region)
//            print("스냅샷이 보는 지도 맵랙트")
//            print(options.mapRect)
//            print("폴리곤의 바운딩맵렉트")
//            print(polygon.boundingMapRect)
//            print("폴리곤의 오버레이 바운딩")
//            print(polygonRenderer.overlay.boundingMapRect)
//            print("폴리곤 로케이션")
//            print(polygonRenderer.polygon.coordinate)
//            if let zoom = mapView.cameraZoomRange {
//                print("맵")
//                print(mapView.region)
//                print("맵줌레벨")
//                print(zoom)
//
//            }
//            print("폴리곤 오리진의 위치")
//            print(snapshot.point(for: polygonRenderer.overlay.boundingMapRect.origin.coordinate))
//            for l in self.polygon.locations {
//                print(snapshot.point(for: l.coordinate))
//            }
//            let rect = MKMapRect(x:  options.mapRect.origin.x,
//                                 y:  options.mapRect.origin.y,
//                                 width: options.mapRect.width,
//                                 height: options.mapRect.width)
//            polygonRenderer.draw(rect, zoomScale: 1, in: context)
//            
//            let image = UIGraphicsGetImageFromCurrentImageContext()
//            UIGraphicsEndImageContext()
//            completion(image)
        }
    }
}
