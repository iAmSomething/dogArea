//
//  TextToImageView.swift
//  dogArea
//
//  Created by 김태훈 on 10/17/23.
//
import SwiftUI
import Foundation
import Observation
struct TextToImageView: View {
    @Bindable var vm = ImageGenerateViewModel()
    var body: some View {
        VStack {
            HStack {
                Text("Provider: \(vm.providerName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            switch vm.fetchPhase {
            case .loading: ProgressView("loading")
            case .success(let image):
                image.resizable().scaledToFit()
            case .failure(let err) :
                Text(err).foregroundStyle(.red)
            case .initial:
                EmptyView()
            }
            HStack {
                TextField("만들 이미지를 입력하세요", text: $vm.prompt)
                    .textFieldStyle(.roundedBorder)
                    .disabled(vm.fetchPhase == .loading)
                Button(action: {
                    Task { await vm.generateImage() }
                }, label: {
                    Text("만들기")
                }).disabled(vm.fetchPhase == .loading || vm.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty )
                
            }
        }
        .padding(.horizontal, 20)
        .navigationTitle("텍스트 투 이미지 테스트")
    }
}
#Preview {
    NavigationStack {
        TextToImageView()
    }
}
