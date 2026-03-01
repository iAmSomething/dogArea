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
          ScrollView(.horizontal) {
              Text("모든 폴리곤 보기")
                  .font(.bold14)
                  .onTapGesture {
                      viewModel.showOnlyOne.toggle()
                  }.padding(.horizontal, 10)
                  .padding(.vertical,5)
                  .background(viewModel.showOnlyOne ? Color.appPeach : Color.appGreen)
                  .cornerRadius(5)
              Text("Heatmap")
                  .font(.bold14)
                  .onTapGesture {
                      viewModel.toggleHeatmapEnabled()
                  }
                  .padding(.horizontal, 10)
                  .padding(.vertical, 5)
                  .background((viewModel.isHeatmapFeatureAvailable && viewModel.heatmapEnabled) ? Color.appYellow : Color.appTextLightGray)
                  .cornerRadius(5)
              Text("근처 핫스팟")
                  .font(.bold14)
                  .onTapGesture {
                      viewModel.toggleNearbyHotspotEnabled()
                  }
                  .padding(.horizontal, 10)
                  .padding(.vertical, 5)
                  .background((viewModel.isNearbyHotspotFeatureAvailable && viewModel.nearbyHotspotEnabled) ? Color.appYellowPale : Color.appTextLightGray)
                  .cornerRadius(5)
              Text("위치 공유")
                  .font(.bold14)
                  .onTapGesture {
                      viewModel.toggleLocationSharing()
                  }
                  .padding(.horizontal, 10)
                  .padding(.vertical, 5)
                  .background((viewModel.isNearbyHotspotFeatureAvailable && viewModel.locationSharingEnabled) ? Color.appGreen : Color.appTextLightGray)
                  .cornerRadius(5)
              Text("시작 카운트다운")
                  .font(.bold14)
                  .onTapGesture {
                      viewModel.toggleWalkStartCountdown()
                  }
                  .padding(.horizontal, 10)
                  .padding(.vertical, 5)
                  .background(viewModel.walkStartCountdownEnabled ? Color.appYellow : Color.appTextLightGray)
                  .cornerRadius(5)
              Text(viewModel.walkPointRecordMode.title)
                  .font(.bold14)
                  .onTapGesture {
                      viewModel.toggleWalkPointRecordMode()
                  }
                  .padding(.horizontal, 10)
                  .padding(.vertical, 5)
                  .background(viewModel.isAutoPointRecordMode ? Color.appGreen : Color.appTextLightGray)
                  .cornerRadius(5)
              Text("모션 축소")
                  .font(.bold14)
                  .onTapGesture {
                      viewModel.toggleMapMotionReduced()
                  }
                  .padding(.horizontal, 10)
                  .padding(.vertical, 5)
                  .background(viewModel.isMapMotionReduced ? Color.appYellowPale : Color.appTextLightGray)
                  .cornerRadius(5)
              Text("자동 종료 정책 v1(고정)")
                  .font(.bold14)
                  .padding(.horizontal, 10)
                  .padding(.vertical, 5)
                  .background(Color.appYellowPale)
                  .cornerRadius(5)
          }.padding(.horizontal)
        Spacer()
        Image(systemName: "clear")
          .resizable()
          .frame(width: 30, height: 30)
          .padding()
          .onTapGesture {dismiss()}
      }
      VStack(alignment: .leading, spacing: 4) {
          Text(viewModel.autoEndPolicySummaryText)
              .font(.appFont(for: .Medium, size: 12))
              .foregroundStyle(Color.appTextDarkGray)
          Text(viewModel.autoEndPolicyHintText)
              .font(.appFont(for: .Light, size: 11))
              .foregroundStyle(Color.appTextLightGray)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 16)
      .padding(.bottom, 8)
      if viewModel.isHeatmapFeatureAvailable && viewModel.heatmapEnabled {
          VStack(alignment: .leading, spacing: 6) {
              Text(viewModel.seasonTileStatusSummaryText)
                  .font(.appFont(for: .Medium, size: 12))
                  .foregroundStyle(Color.appTextDarkGray)
              ScrollView(.horizontal, showsIndicators: false) {
                  HStack(spacing: 6) {
                      ForEach(viewModel.seasonTileLegendItems) { item in
                          HStack(spacing: 4) {
                              Circle()
                                  .fill(viewModel.heatmapColor(for: Double(item.level + 1) / 4.0))
                                  .frame(width: 10, height: 10)
                              Text("\(item.label) \(item.status)")
                                  .font(.appFont(for: .Light, size: 10))
                          }
                          .padding(.horizontal, 8)
                          .padding(.vertical, 5)
                          .background(Color.appYellowPale.opacity(0.45))
                          .cornerRadius(8)
                      }
                  }
              }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 16)
          .padding(.bottom, 8)
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
//                    print(distance)
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
