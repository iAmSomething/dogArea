//
//  WalkDetailView.swift
//  dogArea
//
//  Created by 김태훈 on 11/9/23.
//

import SwiftUI

struct WalkDetailView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: MapViewModel
    @State private var snsCircles: [String] = ["instagram", "twitter"]
    @State private var isMeter: Bool = true
    @State private var image: UIImage? = nil
    @State private var showSaveMessage = false

    var body: some View {
        VStack {
            if image == nil {
                MapCaptureView(captureImage: $image, polygon: viewModel.polygon.polygon!)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .cornerRadius(5)
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    .padding(.bottom,20)
            } else {
                Image(uiImage: image!)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .cornerRadius(5)
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    .padding(.bottom,20)
            }
            HStack {
                SimpleKeyValueView(value: ("영역 넓이", viewModel.calculatedAreaString(areaSize: viewModel.polygon.walkingArea,isPyong: !isMeter)))
                    .padding(.trailing,15)
                    .onTapGesture {isMeter.toggle()}
                SimpleKeyValueView(value: ("산책 시간", "\(viewModel.polygon.walkingTime .simpleWalkingTimeInterval)"))
                    .padding(.leading,15)
            }.padding(.horizontal, 30) 
                .padding(.bottom, 20)
            VStack{
                HStack {
                    Text("공유하기")
                        .padding(.horizontal, 20)
                    Spacer()
                }.frame(maxWidth: .infinity)
                Rectangle()
                    .foregroundColor(.clear)
                    .frame(height: 0.3)
                    .frame(maxWidth: .infinity)
                    .background(Color(red: 0.19, green: 0.19, blue: 0.19))
                    .padding(.horizontal, 20)
                ScrollView(.horizontal) {
                    LazyHGrid(rows: [GridItem(.fixed(32))] , alignment: .top){
                        ForEach(snsCircles.indices) { sns in
                            Circle().foregroundStyle(.gray)
                        }
                    }
                }.frame(height: 60)
                    .padding(.horizontal, 20)
            }
            Spacer()
            Button(action: {
                guard let image = image else { return }
                print("이미지 캡쳐됨")
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                showSaveMessage.toggle()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.showSaveMessage = false
                }
            },
                   label:  {
                Text("저장하기")
                    .foregroundStyle(.black)
            }).frame(maxWidth: .infinity, maxHeight: 50)
                .background(Color(red: 0.99, green: 0.73, blue: 0.73))
                .cornerRadius(15)
                .padding(.horizontal, 70)
            Button(action: {
                viewModel.endWalk(img: image)
                dismiss()
            },
                   label:  {
                Text("확인")
                    .foregroundStyle(.black)
            }).frame(maxWidth: .infinity, maxHeight: 50)
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
        )
    }
}
//
//#Preview {
//    WalkDetailView(viewModel: .init())
//}

struct SimpleKeyValueView: View {
    var value: (String,String)
    var body: some View {
        VStack {
            Text(value.0)
                .font(Font.custom("Inter", size: 18))
                .multilineTextAlignment(.center)
                .foregroundColor(.black)
            Text(value.1)
                .font(Font.custom("Inter", size: 18))
                .multilineTextAlignment(.center)
                .foregroundColor(.black)
        }.foregroundColor(.clear)
            .frame(maxWidth: .infinity, maxHeight:.infinity)
            .aspectRatio(contentMode: .fit)
            .background(.white)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .inset(by: 0.5)
                    .stroke(.black, lineWidth: 1)
            )
            .aspectRatio(contentMode: .fit)
    }
}
