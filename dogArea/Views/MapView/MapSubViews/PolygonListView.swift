//
//  PolygonListView.swift
//  dogArea
//
//  Created by 김태훈 on 10/20/23.
//

import SwiftUI

struct PolygonListView: View {
  @ObservedObject var viewModel: MapViewModel
  @EnvironmentObject var myAlert: CustomAlertViewModel
    var body: some View {
      List(viewModel.polygonList) { item in
        HStack{
          Text(item.createdAt.createdAtTimeDescription)
            .font(.system(size: 10))
            .onTapGesture {
              print(viewModel.polygonList.map{$0.createdAt.createdAtTimeDescription})
              viewModel.polygon = item
              if let polygonCenter = item.polygon?.coordinate {
                viewModel.location = .init(latitude: polygonCenter.latitude, longitude: polygonCenter.longitude)
              }
            }
          Image(systemName: "trash.circle")
            .resizable()
            .frame(width: 20,height: 20)
            .onTapGesture {
              viewModel.deletePolygon(id: item.id)
            }
        }
      }.listStyle(.plain)
    }
}


