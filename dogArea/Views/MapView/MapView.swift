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
  
  var body : some View {
    ZStack{
      
      Map(position: $viewModel.cameraPosition,
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
              viewModel.selectedMarker = location
              myAlert.callAlert(type: .annotationSelected(location))
            }
          }
        }
        if let walkArea = viewModel.polygon.polygon{
          if viewModel.showOnlyOne {
            MapPolygon(walkArea)
              .stroke(.blue, lineWidth: 0.5)
              .foregroundStyle(.cyan.opacity(0.3))
              .annotationTitles(.visible)
          }
          else {
            ForEach(viewModel.polygonList) { item in
              if let p  = item.polygon {
                MapPolygon(p)
                  .stroke(.blue, lineWidth: 0.5)
                  .foregroundStyle(.cyan.opacity(0.3))              .annotationTitles(.visible)
              }
            }
          }
        }
        else { }
      }.safeAreaPadding(.top, 50)
          .mapControls {
            mapControls
          }
          .onAppear{
            //        setRegion(viewModel.location)
          }
      MapAlertSubView(viewModel: viewModel, myAlert: myAlert)
      PolygonListView(viewModel: viewModel, myAlert: myAlert)
        .frame(maxWidth: screenSize.width * 0.4, maxHeight: 150)
        .position(x:screenSize.width * 0.20,
                  y:screenSize.height * 0.20)
      
      if viewModel.isWalking {
        Text("산책 한 지 \(viewModel.time.walkingTimeInterval) 지났습니다")
          .font(.customFont(size: 13))
          .aspectRatio(contentMode: .fit)
          .padding(.horizontal, 5)
          .padding(.vertical, 2)
          .background(.white)
          .cornerRadius(3)
          .position(x:screenSize.width * 0.50,
                    y:screenSize.height * 0.75)
        addPointBtn
      }
      else {
        Button("전부 보여주기", action:{viewModel.showOnlyOne.toggle()
          viewModel.setTrackingMode()})
        
        .position(x:screenSize.width * 0.90,
                  y:screenSize.height * 0.65)
      }
#if DEBUG
        Button("전부삭제", action: viewModel.deleteAllPolygons)
          .position(x:screenSize.width * 0.90,
                    y:screenSize.height * 0.65)
#endif
      startBtn
    }.onMapCameraChange(frequency: .onEnd) {context in
      //      print(viewModel.location)
      //      print(viewModel.cameraPosition.region?.center)
      //      print()
    }
  }
  var addPointBtn: some View {
    Image(.addPointBtn)
      .resizable()
      .frame(width: 55, height: 55)
      .position(x:screenSize.width * 0.90,
                y:screenSize.height * 0.85)
      .onTapGesture {
        viewModel.setTrackingMode()
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
    }.mapControlVisibility(.visible)
  }
}
#Preview {
  MapView()
}
