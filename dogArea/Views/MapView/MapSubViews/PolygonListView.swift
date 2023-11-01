//
//  PolygonListView.swift
//  dogArea
//
//  Created by 김태훈 on 10/20/23.
//

import SwiftUI
import _MapKit_SwiftUI
struct PolygonListView: View {
  @ObservedObject var viewModel: MapViewModel
  @ObservedObject var myAlert: CustomAlertViewModel
  @State var isOpened: Bool = false
  var body: some View {
    VStack(spacing: 0) {
      Button(action: {isOpened.toggle()}, label: {
        if (isOpened && !viewModel.isWalking) {
          Text("접기")
            .font(.system(size: 12))
            .foregroundColor(.black)
            .aspectRatio(contentMode: .fit)
        }
        else {
          Text("영역 목록 보기")      
            .font(.system(size: 12))
            .foregroundColor(.black)
            .aspectRatio(contentMode: .fit)
        }
      })
      .frame(maxWidth: 200, maxHeight: 50)
      .aspectRatio(contentMode: .fit)
      .background(Color.white)
      .cornerRadius(10)
      if (isOpened && !viewModel.isWalking){
        List(viewModel.polygonList) { item in
          HStack{
            Text(item.createdAt.createdAtTimeDescription)
              .font(.system(size: 10))
              .onTapGesture {
                viewModel.polygon = item
                if let polygonCenter = item.polygon?.coordinate,
                   let distance = item.polygon?.boundingMapRect.width {
                  print(distance)
                  viewModel.setRegion(polygonCenter, distance: distance)
                }
              }
            Image(systemName: "trash.circle")
              .resizable()
              .frame(width: 20,height: 20)
              .onTapGesture {
                myAlert.callAlert(type: .deletePolygon(item.id))
              }
          }
        }.listStyle(.plain)
          .transition(.scale)
      }
    }
  }
}


