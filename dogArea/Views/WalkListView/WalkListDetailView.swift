//
//  WalkListDetailView.swift
//  dogArea
//
//  Created by 김태훈 on 11/13/23.
//

import SwiftUI
import MapKit
struct WalkListDetailView: View {
    @Environment(\.dismiss) var dismiss
    @State var model: WalkDataModel
    @State private var isMeter: Bool = true
    @State private var showSaveMessage: String? = nil
    @State private var selectedLoc: UUID? = nil
    @StateObject var tabStatus = TabAppear.shared
    @StateObject var imageRenderer = MapImageProvider()
    var body: some View {
        let tempPolygon = model.toPolygon()
        ScrollView{
            VStack {
                HStack {
                    Text("산책한 영역")
                        .padding(.horizontal, 20)
                        .font(.appFont(for: .SemiBold, size: 20))
                    Spacer()
                }.frame(maxWidth: .infinity)
                UnderLine()
                SimpleMapView(polygon: tempPolygon, selectedLocation: $selectedLoc)
                    .frame(maxWidth: .infinity , minHeight: screenSize.width - 40, maxHeight: .infinity)
                    .cornerRadius(5)
                    .padding(.horizontal, 20)
                    .padding(.bottom,20)
                HStack {
                    SimpleKeyValueView(value: ("영역 넓이","\(calculatedAreaString(areaSize: model.walkArea , isPyong : !isMeter))"))
                        .onTapGesture {isMeter.toggle()}
                    Spacer()
                    SimpleKeyValueView(value: ("산책 시간","\(model.walkDuration.simpleWalkingTimeInterval)"))
                }.frame(maxWidth: .infinity)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 20)
                VStack{
                    HStack {
                        Text("영역 표시한 곳")
                            .padding(.horizontal, 20)
                            .font(.appFont(for: .SemiBold, size: 20))

                        Spacer()
                    }.frame(maxWidth: .infinity)
                    UnderLine()
                    ScrollView(.horizontal) {
                        LazyHGrid(rows: [GridItem(.fixed(32))] , alignment: .top){
                            ForEach(model.locations) { loc in
                                Text("\(loc.createdAt.createdAtTimeHHMM)")
                                    .font(.appFont(for: .Medium, size: 14))
                                    .padding(5)
                                    .foregroundStyle(Color.appTextDarkGray)
                                    .background(self.selectedLoc == loc.id ? Color.appPeach : Color.appYellowPale)
                                    .cornerRadius(5)
                                    .onTapGesture {
                                        self.selectedLoc = loc.id
                                    }
                            }
                        }
                    }.frame(height: 60)
                        .padding(.horizontal, 20)
                }
                Button(action: {
                    if let img = imageRenderer.capturedImage {
                        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                        showSaveMessage = "사진을 저장했어요!"
                    } else {
                        showSaveMessage = "사진 저장에 실패했어요"
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        showSaveMessage = nil
                    }
                },
                       label:  {
                    Text("사진으로 저장하기")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .foregroundStyle(.black)
                }).frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color(red: 0.99, green: 0.73, blue: 0.73))
                    .cornerRadius(15)
                    .padding(.horizontal, 70)
                Spacer()
                Button(action: {
                    tabStatus.appear()
                    dismiss()
                },
                       label:  {
                    Text("확인")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .foregroundStyle(.black)
                }).frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color(red: 0.99, green: 0.73, blue: 0.73))
                    .cornerRadius(15)
                    .padding(.horizontal, 70)
            }.overlay(
                Group {
                    if let msg = showSaveMessage {
                        SimpleMessageView(message: msg)
                            .transition(.opacity)
                    }
                }.animation(.easeInOut(duration: 0.2))
            ).navigationBarBackButtonHidden()
        }.padding(.top, 20)
        .onAppear {
            imageRenderer.captureMapImage(for: model.toPolygon().polygon!)

            tabStatus.hide()
        }.safeAreaPadding(.top, 20)
            .onDisappear {
                tabStatus.appear()
            }

    }
    func calculatedAreaString(areaSize: Double , isPyong: Bool = false) -> String {
        var str = String(format: "%.2f" , areaSize) + "㎡"
        if areaSize > 10000.0 {
            str = String(format: "%.2f" , areaSize/10000) + "만 ㎡"
        }
        if areaSize > 100000.0 {
            str = String(format: "%.2f" , areaSize/1000000) + "k㎡"
        }
        if isPyong {
            if areaSize/3.3 > 10000 {
                str = String(format: "%.1f" , areaSize/33333) + "만 평"

            } else {
                str = String(format: "%.1f" , areaSize/3.3) + "평"
            }
        }
        return str
    }
}
