//
//  HomeView.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import SwiftUI

struct HomeView: View {
  @State private var showModal = false
  @State private var settingsDetent = PresentationDetent.medium
    @State private var isRender: Color = .appRed
    @State private var renderedImg: UIImage? = nil
    @State private var comment: String = "red"

    var body: some View {
        VStack{
            if let img = renderedImg {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal,60)
            }
            Text(comment).frame(width: 300,height: 300)
                .foregroundStyle(.black)
                .background(isRender)
                .shadow(radius: 5)
                .renderImage{ img in
                    DispatchQueue.main.async {
                        self.renderedImg = img
                    }
                }
                .onTapGesture {
                    isRender = isRender == .appRed ? .appHotPink : .appRed
                    comment = comment == "red" ? "hotpink" : "red"
                }

            Button("Show Modal") {
                withAnimation {
                    self.showModal = true
                }
            }
            .sheet(isPresented: $showModal) {
                ProfileSettingsView()
                    .presentationDetents([.medium],
                                         selection: $settingsDetent)
//                    .interactiveDismissDisabled(true)
                
            }
        }
    }
}

#Preview {
    HomeView()
}
struct TextView: View {
    @Binding var text: String
    var body: some View {
        Color.blue.opacity(0.5)
            .cornerRadius(20)
            .frame(width: 250, height: 100, alignment: .center)
            .overlay(
                Text(text)
                    .font(.largeTitle)
            )
            .edgesIgnoringSafeArea(.all)
    }
}
