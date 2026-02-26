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
    @EnvironmentObject var authFlow: AuthFlowCoordinator
    @Bindable var vm = ImageGenerateViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Text("\(vm.selectedPetName) 캐리커처")
                .font(.appFont(for: .SemiBold, size: 24))
                .padding(.top, 20)

            switch vm.fetchPhase {
            case .loading:
                ProgressView("캐리커처 생성 중...")
                    .frame(maxWidth: .infinity)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Text("생성 완료: 프로필에 바로 반영되었습니다.")
                    .font(.appFont(for: .Regular, size: 13))
                    .foregroundStyle(Color.appGreen)
            case .failure(let err):
                VStack(spacing: 8) {
                    Text(err)
                        .font(.appFont(for: .Regular, size: 13))
                        .foregroundStyle(Color.appRed)
                    Button("다시 시도") {
                        guard authFlow.requestAccess(feature: .aiGeneration) else {
                            return
                        }
                        Task { await vm.retryLastRequest() }
                    }
                    .font(.appFont(for: .SemiBold, size: 13))
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
            case .initial:
                Text("프로필에 등록된 반려견 사진을 캐리커처 스타일로 변환합니다.")
                    .font(.appFont(for: .Regular, size: 13))
                    .foregroundStyle(Color.appTextDarkGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Button(action: {
                guard authFlow.requestAccess(feature: .aiGeneration) else {
                    return
                }
                Task { await vm.generateImage() }
            }, label: {
                Text(vm.fetchPhase == .loading ? "생성 중..." : "캐리커처 생성")
                    .frame(maxWidth: .infinity)
            })
            .buttonStyle(.borderedProminent)
            .disabled(vm.fetchPhase == .loading)
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
        .onAppear {
            vm.reloadSelectedPetContext()
        }
        .navigationTitle("프로필 캐리커처")
    }
}

#Preview {
    NavigationStack {
        TextToImageView()
    }
}
