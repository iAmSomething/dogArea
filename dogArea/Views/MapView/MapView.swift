//
//  MapView.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import Foundation
import SwiftUI
import _MapKit_SwiftUI

struct MapView : View{
  @ObservedObject private var myAlert: CustomAlertViewModel = .init()
  @ObservedObject private var viewModel = MapViewModel()
  @State private var camera: MapCamera = .init(.init())
  @State private var cameraPosition =
  MapCameraPosition.userLocation(fallback: .automatic)
  //    .region(
  //    MKCoordinateRegion(
  //      center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
  //      span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
  //    ))
  // Marker 선택 상태 저장
  @State private var selectedMarker: Location? = nil
  var body : some View {
    ZStack{
      Map(position: $cameraPosition,
          interactionModes: .all){
        ForEach(viewModel.polygon.locations) { location in
          Annotation("", coordinate: location.coordinate) {
            ZStack {
              RoundedRectangle(cornerRadius: 5)
                .fill(Color.yellow)
              Text("💦")
                .padding(5)
            }
            .onTapGesture {
              selectedMarker = location
              myAlert.callAlert(type: .annotationSelected(location))
            }
          }
        }
        if viewModel.polygon.locations.count >= 3 {
          MapPolygon(viewModel.polygon.polygon)
            .stroke(.blue, lineWidth: 0.5)
            .foregroundStyle(.cyan)
        }
      }
          .onAppear{
            //        setRegion(viewModel.location)
          }
      alertView
      Image(.addPointBtn)
        .resizable()
        .frame(width: 55, height: 55)
        .position(x:screenSize.width * 0.90,
                  y:screenSize.height * 0.85)
        .onTapGesture {
          myAlert.alertType = .addPoint
          myAlert.callAlert(type: .addPoint)}
      Button(action:{
        viewModel.endWalk()
      }){
        Text("산책 종료")
      }
      
    }
    //    .alert(item:$selectedMarker){ marker -> Alert in // 마커 선택에 따른 알림창 처리
    //      Alert(title : Text("마커 삭제"),
    //            message : Text("선택한 마커를 삭제하시겠습니까?"),
    //            primaryButton:.destructive(Text("확인")){
    //        viewModel.removeLocation(marker.id)
    //      },
    //            secondaryButton:.cancel(Text("취소"))
    //      )
    //    }
    .onMapCameraChange {context in
      camera = context.camera
      //      setRegion(viewModel.location)
      
    }
    
  }
  var alertView: some View {
    if myAlert.isAlert {
      var ca : CustomAlert
      switch myAlert.alertType {
      case .addPoint :
        ca = CustomAlert(presentAlert: $myAlert.isAlert,
                         alertModel: myAlert.alertType.model,
                         leftButtonAction: {
          viewModel.location = .init(latitude: camera.centerCoordinate.latitude,
                                     longitude: camera.centerCoordinate.longitude)
          viewModel.addLocation()
        },rightButtonAction: {print("right")})
      case .annotationSelected(let loc) :
        ca = CustomAlert(presentAlert: $myAlert.isAlert,
                         alertModel: myAlert.alertType.model,
                         leftButtonAction: {
        },rightButtonAction: {
          if let marker = selectedMarker {
            viewModel.removeLocation(marker.id)
          }})
      case .custom(_), .logOut:
        ca = CustomAlert(presentAlert: $myAlert.isAlert,
                         alertModel: myAlert.alertType.model)
      }
      return AnyView(ca)
    }
    else {
      return AnyView(EmptyView())
    }
  }
  func setRegion(_ location : CLLocation?){
    guard let coordinate=location?.coordinate else {return}
    camera.centerCoordinate.latitude=coordinate.latitude - 0.01
    camera.centerCoordinate.longitude=coordinate.longitude - 0.01
  }
  func seeCurrentLocation(){
    MapCameraPosition.userLocation(followsHeading: true, fallback: self.cameraPosition)
  }
}
#Preview {
  MapView()
}
