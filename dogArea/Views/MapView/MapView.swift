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
    @ObservedObject var viewModel: MapViewModel = .init()
    @State private var isModalPresented = false
    @State private var isWalkingViewPresented = false
    @State private var endWalkingViewPresented = false
    @State private var isCameraSeeingSomewhere: Bool = false
    @State private var distance = 0.0
    @State private var selectedPolygonData: WalkDataModel? = nil
    @ObservedObject var tabStatus = TabAppear.shared
    
    var body : some View {
        ZStack{
            MapSubView(myAlert: myAlert, viewModel: viewModel)
            MapAlertSubView(viewModel: viewModel, myAlert: myAlert)
            
            VStack {
                Spacer().frame(height: 50)
                HStack {
                    Spacer()
                    Button(action:{
                        viewModel.fetchPolygonList()
                        isModalPresented.toggle()
                    }, label: {
                        Text("설정")
                            .font(.appFont(for: .Bold, size: 16))
                            .foregroundStyle(Color.appTextDarkGray)
                            .padding(7)
                            .background(Color.appYellow)
                            .cornerRadius(10)
                    })
                }
                Spacer()
                
                if viewModel.isWalking {
                    HStack {
                        if isCameraSeeingSomewhere,
                           let loc = viewModel.location{
                            Button(action: {viewModel.setRegion(loc,distance: 2000)}, label: {Text("내 위치 보기")})
                                .buttonStyle(.borderedProminent)
                                .padding(.leading)
                        }
                        Spacer()
                        addPointBtn
                    }
                } else {
                    HStack {
                        if isCameraSeeingSomewhere,
                           let loc = viewModel.location{
                            Button(action: {viewModel.setRegion(loc,distance: 2000)}, label: {Text("내 위치 보기")})
                                .buttonStyle(.borderedProminent)
                                .padding(.leading)
                        }
                        Spacer()
                    }
                    
                }
                StartButtonView(viewModel: viewModel,
                                myAlert: myAlert,
                                isModalPresented: $isWalkingViewPresented,
                                endWalkingViewPresented: $endWalkingViewPresented)
                if !viewModel.selectedPolygonList.isEmpty && !viewModel.isWalking {
                    VStack {
                        Text("닫기")
                            .frame(maxWidth: .infinity, maxHeight: 20)
                            .onTapGesture {
                                viewModel.selectedPolygonList = []
                            }.padding()
                            .aspectRatio(contentMode: .fit)
                        UnderLine()
                        ScrollView(.horizontal) {
                            HStack{
                                ForEach(viewModel.selectedPolygonList) { item in
                                    SelectedPolygonCell(walkData: .init(polygon: item))
                                        .onTapGesture {
                                            self.selectedPolygonData = WalkDataModel(polygon: item)
                                        }
                                        .padding()
                                        .myCornerRadius(radius: 15)
                                        .overlay(                                        RoundedRectangle(cornerRadius: 15)
                                            .stroke(Color.appTextDarkGray, lineWidth: 0.3))
                                }.padding(10)
                            }.frame(maxHeight: .infinity)
                                .aspectRatio(contentMode: .fit)
                        }.frame(width: screenSize.width)
                        .aspectRatio(contentMode: .fit)
                    }.frame(maxHeight: .infinity)
                        .aspectRatio(contentMode: .fit)
                        .background(.white)
                        .clipShape(RoundedCornersShape(radius: 20,corners: [.topLeft,.topRight]))
                }
            }
        }
        .onAppear {
            viewModel.updateAnnotations(cameraDistance: self.distance)
            tabStatus.appear()
        }
        .sheet(isPresented: $isModalPresented){
            MapSettingView(viewModel: self.viewModel, myAlert: self.myAlert)
                .presentationDetents([.oneThird])
            
        }.fullScreenCover(isPresented: $isWalkingViewPresented) {
            StartModalView()
                .interactiveDismissDisabled(true)
        }.sheet(isPresented: $endWalkingViewPresented) {
            WalkDetailView(viewModel: viewModel).interactiveDismissDisabled(true)
        }.fullScreenCover(item: $selectedPolygonData, onDismiss: {self.selectedPolygonData = nil}, content: {model in
            WalkListDetailView(model: model)
        })
        .onMapCameraChange{ context in
            if let loc = viewModel.location {
                self.isCameraSeeingSomewhere =  context.camera.centerCoordinate.clLocation.distance(from: loc) > 300
                if !viewModel.showOnlyOne {
                    if Int(context.camera.distance) != Int(self.distance) {
                        self.distance = context.camera.distance
                        viewModel.updateAnnotations(cameraDistance: context.camera.distance)
                    }
                }
            }
        }
    }
    var addPointBtn: some View {
        Image("plusButton")
            .resizable()
            .frame(width: 70, height: 70)
            .onTapGesture {
                viewModel.setTrackingMode()
                myAlert.alertType = .addPoint
                myAlert.callAlert(type: .addPoint)}
    }
    
}
#Preview {
    MapView()
}


