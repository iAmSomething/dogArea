//
//  WalkDetailView.swift
//  dogArea
//
//  Created by 김태훈 on 11/9/23.
//

import SwiftUI
import UIKit
struct WalkDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var loading: LoadingViewModel
    @EnvironmentObject var viewModel: MapViewModel
    @StateObject var mapImageProvider = MapImageProvider()
    @StateObject private var detailViewModel = WalkDetailViewModel()

    private var shareItems: [Any] {
        detailViewModel.shareItems
    }

    var body: some View {
        VStack {
            Image(uiImage: detailViewModel.previewImage(mapCapturedImage: mapImageProvider.capturedImage) ?? UIImage.emptyImg)
                .resizable()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .cornerRadius(5)
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom,20)
                .onAppear {
                    guard let polygon = viewModel.polygon.polygon else { return }
                    Task {
                        mapImageProvider.captureMapImage(for: polygon)
                    }
                }
            HStack {
                SimpleKeyValueView(value: ("영역 넓이", detailViewModel.areaValueText()))
                    .onTapGesture { detailViewModel.toggleAreaUnit() }
                Spacer()
                SimpleKeyValueView(value: ("산책 시간", detailViewModel.durationText()))
            }.frame(maxWidth: .infinity)
                .padding(.horizontal, 30)
                .padding(.bottom, 20)
            if let completionValuePresentation = detailViewModel.completionValuePresentation() {
                WalkCompletionValueFlowCardView(presentation: completionValuePresentation)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
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
                Button(action: {
                    detailViewModel.requestImageInput()
                }, label: {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("사진 찍기")
                    }
                    .font(.appFont(for: .Medium, size: 16))
                    .foregroundStyle(Color.appTextDarkGray)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.appPeach)
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                })
                Button(action: {
                    prepareShareItems()
                }, label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("공유 시트 열기")
                    }
                    .font(.appFont(for: .Medium, size: 16))
                    .foregroundStyle(Color.appTextDarkGray)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.appYellowPale)
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                })
            }
            Spacer()
            Button(action: {
                _ = detailViewModel.saveShareCardToPhotoLibrary(
                    mapCapturedImage: mapImageProvider.capturedImage,
                    onLoading: { loading.loading() },
                    onFailed: { loading.failed(msg: $0) },
                    onSuccess: { loading.success() }
                )
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    detailViewModel.clearToastMessage()
                }
            },
                   label:  {
                Text("저장하기")
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                
            }).frame(maxWidth: .infinity, maxHeight: 50)
                .background(Color(red: 0.99, green: 0.73, blue: 0.73))
                .cornerRadius(15)
                .padding(.horizontal, 70)
                .accessibilityIdentifier("walk.detail.saveToPhotos")
            Button(action: handleConfirmWalkEnd,
                   label:  {
                Text("저장하고 종료")
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
            }).frame(maxWidth: .infinity, maxHeight: 50)
                .background(Color(red: 0.99, green: 0.73, blue: 0.73))
                .cornerRadius(15)
                .padding(.horizontal, 70)
                .accessibilityIdentifier("walk.detail.confirm")
        }.overlay(
            Group {
                if let toastMessage = detailViewModel.toastMessage {
                    SimpleMessageView(message: toastMessage)
                        .transition(.opacity)
                }
            }.animation(.easeInOut(duration: 0.2), value: detailViewModel.toastMessage)
        )
        .sheet(isPresented: $detailViewModel.showShareSheet) {
            ActivityShareSheet(items: shareItems) { _, completed, _, _ in
                detailViewModel.handleShareCompletion(completed: completed)
            }
        }
        .fullScreenCover(isPresented: $detailViewModel.showCameraPicker) {
            ImagePicker(image: $detailViewModel.capturedWalkPhoto, type: .camera)
        }
        .fullScreenCover(isPresented: $detailViewModel.showPhotoLibraryPicker) {
            ImagePicker(image: $detailViewModel.capturedWalkPhoto, type: .photoLibrary)
        }
        .onAppear {
            detailViewModel.bind(context: viewModel)
        }
    }

    /// 공유 시트에 전달할 아이템을 구성하고 공유 플로우를 시작합니다.
    private func prepareShareItems() {
        detailViewModel.prepareShareSheet(mapCapturedImage: mapImageProvider.capturedImage)
    }

    /// 산책 종료 확인 시트를 먼저 닫고 다음 메인 런루프에 실제 종료 저장을 실행합니다.
    private func handleConfirmWalkEnd() {
        let capturedImage = mapImageProvider.capturedImage
        dismiss()
        Task { @MainActor in
            await Task.yield()
            detailViewModel.confirmWalkEnd(mapCapturedImage: capturedImage)
        }
    }
}
//
//#Preview {
//    WalkDetailView(viewModel: .init())
//}
