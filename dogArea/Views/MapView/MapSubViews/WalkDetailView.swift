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
    @State var snsCircles: [String] = ["instagram", "twitter"]
    @State var isMeter: Bool = true
    @State var image: UIImage? = nil
    var body: some View {
        VStack {
            Image(uiImage: image ?? UIImage(systemName: "car.fill")!)
                .resizable()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .cornerRadius(5)
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom,20)
                .onAppear() {
                    self.image = viewModel.renderToImage()
                }
            HStack {
                SimpleKeyValueView(value: ("영역 넓이", viewModel.calculatedAreaString(isPyong: !isMeter)))
                    .padding(.trailing,15)
                    .onTapGesture {isMeter.toggle()}
                SimpleKeyValueView(value: ("산책 시간", "\(viewModel.time.simpleWalkingTimeInterval)"))
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
            Button(action: {dismiss()},
                   label:  {
                Text("저장하기")
                    .foregroundStyle(.black)
            }).frame(maxWidth: .infinity, maxHeight: 50)
                .background(Color(red: 0.99, green: 0.73, blue: 0.73))
                .cornerRadius(15)
                .padding(.horizontal, 70)
            Button(action: {dismiss()},
                   label:  {
                Text("확인")
                    .foregroundStyle(.black)
            }).frame(maxWidth: .infinity, maxHeight: 50)
                .background(Color(red: 0.99, green: 0.73, blue: 0.73))
                .cornerRadius(15)
                .padding(.horizontal, 70)
        }
    }
}

#Preview {
    WalkDetailView(viewModel: .init())
}

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
