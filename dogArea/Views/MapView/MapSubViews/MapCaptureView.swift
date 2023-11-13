import SwiftUI
import MapKit
struct MapCaptureView: UIViewRepresentable {
    @Binding var captureImage: UIImage?
    let polygon: MKPolygon
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        mapView.delegate = context.coordinator
        mapView.camera.centerCoordinate = polygon.coordinate
        mapView.cameraBoundary = MKMapView.CameraBoundary(mapRect: polygon.boundingMapRect)
        mapView.addOverlay(polygon)
        mapView.setVisibleMapRect(polygon.boundingMapRect, edgePadding: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20), animated: false)
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
        mapView.cameraBoundary = MKMapView.CameraBoundary(mapRect: polygon.boundingMapRect)
        mapView.addOverlay(polygon)
        mapView.setVisibleMapRect(polygon.boundingMapRect, edgePadding: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20), animated: false)
        mapView.setCameraBoundary(mapView.cameraBoundary, animated: false)
        print("맵뷰 사이즈\(mapView.frame.size)")
        print("맵뷰 오버레이 개수\(mapView.overlays.count)")
        print("폴리곤 바운딩\(polygon.boundingMapRect)")
        print("카메라 바운더리 \(mapView.cameraBoundary)")


        options.region = mapView.region
        if mapView.frame.size == CGSize(width: 0, height: 0) {
            options.size = CGSize(width: 300, height: 300)
        } else {
            options.size = mapView.frame.size
        }
        
        let snapshotter = MKMapSnapshotter(options: options)

        snapshotter.start(with: .main) { snapshot, error in
            guard let snapshot = snapshot, error == nil else {
                completion(nil)
                return
            }
            let renderer = UIGraphicsImageRenderer(bounds: CGRect(x: 0, y: 0, width: snapshot.image.size.width, height: snapshot.image.size.height))
            let image = renderer.image { context in
                snapshot.image.draw(at: .zero)
                let topLeftCoordinate = CLLocationCoordinate2D(latitude: polygon.boundingMapRect.maxY,
                                                               longitude: polygon.boundingMapRect.minX)
                let topLeftPoint = snapshot.point(for: topLeftCoordinate)
                context.cgContext.translateBy(x: -topLeftPoint.x, y: -topLeftPoint.y)

                let polygonRenderer = MKPolygonRenderer(polygon: polygon)
                polygonRenderer.fillColor = UIColor.red.withAlphaComponent(0.5)
                polygonRenderer.strokeColor = UIColor.red
                polygonRenderer.lineWidth = 2
                let rect = polygonRenderer.overlay.boundingMapRect
                let zoomScale = MKZoomScale(mapView.bounds.width / CGFloat(mapView.visibleMapRect.size.width))
                polygonRenderer.draw(rect, zoomScale: zoomScale, in: context.cgContext)
            }
            completion(image)
        }
    }
}
