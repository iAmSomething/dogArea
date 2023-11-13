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
    @State private var image: UIImage? = nil
    var body : some View {
        ZStack{
            MapSubView(myAlert: myAlert, viewModel: viewModel)
//                .renderImage($image)
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
                        Spacer()
                        addPointBtn
                    }
                }
                StartButtonView(viewModel: viewModel,
                                myAlert: myAlert,
                                isModalPresented: $isWalkingViewPresented,
                                endWalkingViewPresented: $endWalkingViewPresented)
            }
        }
        .sheet(isPresented: $isModalPresented){
            MapSettingView(viewModel: viewModel, myAlert: myAlert)
                .presentationDetents([.oneThird])
        }.fullScreenCover(isPresented: $isWalkingViewPresented) {
            StartModalView()
                .interactiveDismissDisabled(true)
        }.sheet(isPresented: $endWalkingViewPresented) {
            WalkDetailView(viewModel: viewModel).interactiveDismissDisabled(true)
        }
        
    }
    var addPointBtn: some View {
        Image("plusButton")
            .resizable()
            .frame(width: 55, height: 55)
            .onTapGesture {
                viewModel.setTrackingMode()
                myAlert.alertType = .addPoint
                myAlert.callAlert(type: .addPoint)}
    }

}
#Preview {
    MapView()
}


