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
    @EnvironmentObject var loading: LoadingViewModel
    @EnvironmentObject var authFlow: AuthFlowCoordinator
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
                if viewModel.hasRecoverableWalkSession && !viewModel.isWalking {
                    recoverableSessionBanner
                }
                if viewModel.shouldShowWatchStatus {
                    watchStatusBanner
                }
                if viewModel.hasRuntimeGuardStatus {
                    runtimeGuardBanner
                }
                if viewModel.hasSyncOutboxStatus {
                    syncOutboxBanner
                }
                if authFlow.isGuestMode && !viewModel.isWalking && !viewModel.polygonList.isEmpty {
                    guestBackupBanner
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
            viewModel.reloadSelectedPetContext()
            viewModel.updateAnnotations(cameraDistance: self.distance)
            tabStatus.appear()
        }
        .onChange(of: viewModel.walkStatusMessage) { newValue in
            guard newValue != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                viewModel.clearWalkStatusMessage()
            }
        }
        .onChange(of: viewModel.runtimeGuardStatusText) { newValue in
            guard newValue.isEmpty == false else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                viewModel.clearRuntimeGuardStatus()
            }
        }
        .sheet(isPresented: $isModalPresented){
            MapSettingView(viewModel: self.viewModel, myAlert: self.myAlert)
                .presentationDetents([.oneThird])
            
        }.fullScreenCover(isPresented: $isWalkingViewPresented) {
            StartModalView(
                petName: viewModel.selectedPetName,
                onCompleted: { viewModel.startWalkNow() }
            )
            .interactiveDismissDisabled(true)
        }.sheet(isPresented: $endWalkingViewPresented) {
            WalkDetailView()
                .environmentObject(loading)
                .environmentObject(viewModel).interactiveDismissDisabled(true)
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
        .overlay(alignment: .top) {
            if let message = viewModel.walkStatusMessage {
                Text(message)
                    .font(.appFont(for: .SemiBold, size: 13))
                    .foregroundStyle(Color.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.appYellow)
                    .cornerRadius(10)
                    .padding(.top, 12)
            }
        }
    }

    var recoverableSessionBanner: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("미종료 산책 감지")
                    .font(.appFont(for: .SemiBold, size: 13))
                Text(viewModel.recoverableWalkSummaryText)
                    .font(.appFont(for: .Light, size: 11))
                    .foregroundStyle(Color.appTextDarkGray)
            }
            Spacer()
            Button("복구") {
                viewModel.resumeRecoverableWalkSession()
            }
            .font(.appFont(for: .SemiBold, size: 12))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.appGreen)
            .cornerRadius(8)
            Button("지금 종료") {
                viewModel.finalizeRecoverableWalkSessionNow()
            }
            .font(.appFont(for: .SemiBold, size: 12))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.appTextLightGray)
            .cornerRadius(8)
        }
        .padding(10)
        .background(Color.white.opacity(0.95))
        .cornerRadius(12)
        .padding(.horizontal, 12)
    }

    var watchStatusBanner: some View {
        VStack(spacing: 3) {
            Text(viewModel.watchSyncStatusText)
                .font(.appFont(for: .Light, size: 11))
                .foregroundStyle(Color.appTextDarkGray)
            if viewModel.latestWatchActionText.isEmpty == false {
                Text(viewModel.latestWatchActionText)
                    .font(.appFont(for: .Light, size: 11))
                    .foregroundStyle(Color.appTextDarkGray)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.9))
        .cornerRadius(8)
        .padding(.top, 4)
    }

    var runtimeGuardBanner: some View {
        Text(viewModel.runtimeGuardStatusText)
            .font(.appFont(for: .Light, size: 11))
            .foregroundStyle(Color.appRed)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.9))
            .cornerRadius(8)
            .padding(.top, 2)
    }

    var syncOutboxBanner: some View {
        Text(viewModel.syncOutboxStatusText)
            .font(.appFont(for: .Light, size: 11))
            .foregroundStyle(Color.appTextDarkGray)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.9))
            .cornerRadius(8)
            .padding(.top, 2)
    }

    var guestBackupBanner: some View {
        HStack(spacing: 8) {
            Text("게스트 기록은 이 기기에만 저장돼요.")
                .font(.appFont(for: .Light, size: 11))
                .foregroundStyle(Color.appTextDarkGray)
            Spacer()
            Button("로그인하고 백업") {
                _ = authFlow.requireMember(trigger: .walkBackup)
            }
            .font(.appFont(for: .SemiBold, size: 11))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.appYellow)
            .cornerRadius(8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.9))
        .cornerRadius(8)
        .padding(.top, 2)
    }

    var addPointBtn: some View {
        VStack(spacing: 6) {
            if viewModel.isAutoPointRecordMode {
                Text("AUTO")
                    .font(.appFont(for: .SemiBold, size: 11))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.appGreen)
                    .cornerRadius(6)
            }
            Image("plusButton")
                .resizable()
                .frame(width: 70, height: 70)
                .onTapGesture {
                    viewModel.setTrackingMode()
                    myAlert.alertType = .addPoint
                    myAlert.callAlert(type: .addPoint)
                }
        }
    }
    
}
#Preview {
    MapView()
}
