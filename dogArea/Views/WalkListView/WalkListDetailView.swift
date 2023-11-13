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
    @ObservedObject var viewModel: WalkListViewModel
    @State var model: WalkDataModel
    @State private var isMeter: Bool = true
    @State private var showSaveMessage = false
    @State private var selectedLoc: UUID? = nil
    @ObservedObject var tabStatus = TabAppear.shared
    
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
                    SimpleKeyValueView(value: ("영역 넓이","\(viewModel.calculatedAreaString(areaSize: model.walkArea , isPyong : !isMeter))"))
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
                    if showSaveMessage {
                        SimpleMessageView(message: "저장이 완료되었습니다")
                            .transition(.opacity)
                        
                    }
                }.animation(.easeInOut(duration: 0.2))
            ).navigationBarBackButtonHidden()
        }.padding(.top, 20)
        .onAppear {
            tabStatus.hide()
        }.safeAreaPadding(.top, 20)
    }
}
