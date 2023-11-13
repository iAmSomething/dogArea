//
//  MapSettingView.swift
//  dogArea
//
//  Created by 김태훈 on 11/8/23.
//

import SwiftUI

struct MapSettingView: View {
  @Environment(\.dismiss) var dismiss
  
  @ObservedObject var viewModel: MapViewModel
  @ObservedObject var myAlert: CustomAlertViewModel
  var body: some View {
    VStack {
      HStack{
        Spacer()
        Image(systemName: "clear")
          .resizable()
          .frame(width: 30, height: 30)
          .padding()
          .onTapGesture {dismiss()}
      }
     Text("모든 폴리곤 보기")
        .font(.bold14)
        .onTapGesture {
          viewModel.showOnlyOne = false
          dismiss()
        }
      List {
        Section(content: {
          ForEach(viewModel.polygonList) { item in
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
                    dismiss()
                  myAlert.callAlert(type: .deletePolygon(item.id))
                }
            }
          }
        } , header: {Text("산책 목록")})
        
      }
    }
  }
}
