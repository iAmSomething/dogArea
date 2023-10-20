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
  @ObservedObject var myAlert: CustomAlertViewModel = .init()
  @ObservedObject private var viewModel = MapViewModel()
  @State private var camera: MapCamera = .init(.init())
  @State private var cameraPosition = MapCameraPosition.userLocation( followsHeading: true,fallback: .automatic)
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
        if let walkArea = viewModel.polygon.polygon{
          MapPolygon(walkArea)
            .stroke(.blue, lineWidth: 0.5)
            .foregroundStyle(.cyan)
        }
        else {
          
        }
      }.safeAreaPadding(.top, 50)
          .mapControls {
        mapControls
      }
          .onAppear{
            //        setRegion(viewModel.location)
          }
      alertView
      PolygonListView(viewModel: viewModel)
        .frame(maxWidth: screenSize.width * 0.4, maxHeight: 150)
        .position(x:screenSize.width * 0.20,
                  y:screenSize.height * 0.20)
      
      if viewModel.isWalking {
        Text("산책 한 지 \(viewModel.time.walkingTimeInterval) 지났습니다")
        addPointBtn
        #if DEBUG
        Button("전부삭제", action: viewModel.deleteAllPolygons)
          .position(x:screenSize.width * 0.90,
                    y:screenSize.height * 0.65)
        #endif
      }
      startBtn
    }
    .onMapCameraChange {context in
      camera = context.camera
      //      setRegion(viewModel.location)
      
    }
  }
  var addPointBtn: some View {
    Image(.addPointBtn)
      .resizable()
      .frame(width: 55, height: 55)
      .position(x:screenSize.width * 0.90,
                y:screenSize.height * 0.85)
      .onTapGesture {
        myAlert.alertType = .addPoint
        myAlert.callAlert(type: .addPoint)}
  }
  var startBtn: some View {
    Image(viewModel.isWalking ? .stopIcon : .startIcon)
      .resizable()
      .aspectRatio(contentMode: .fit)
      .frame(width: 64, height: 64)
      .position(x:screenSize.width * 0.5,
                y:screenSize.height * 0.85)
      .onTapGesture {
        viewModel.endWalk()
      }
  }
  var mapControls: some View {
    VStack{
      MapUserLocationButton()
      MapScaleView()
      MapPitchToggle()
    }
    .mapControlVisibility(.visible)
  }
  var alertView: some View {
    if myAlert.isAlert {
      var ca : CustomAlert
      switch myAlert.alertType {
      case .addPoint :
        ca = CustomAlert(presentAlert: $myAlert.isAlert,
                         alertModel: myAlert.alertType.model,
                         leftButtonAction: {
          if let cam = cameraPosition.camera {
            print("\(cam.centerCoordinate.latitude), \(cam.centerCoordinate.longitude)")
          }
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
