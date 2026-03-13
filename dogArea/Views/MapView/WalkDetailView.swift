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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                previewSection
                metricSection

                if let completionValuePresentation = detailViewModel.completionValuePresentation() {
                    WalkCompletionValueFlowCardView(presentation: completionValuePresentation)
                }

                shareSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 20)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomActionSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(
            Group {
                if let toastMessage = detailViewModel.toastMessage {
                    SimpleMessageView(message: toastMessage)
                        .transition(.opacity)
                }
            }.animation(.easeInOut(duration: 0.2), value: detailViewModel.toastMessage)
        )
        .background(
            ActivityShareSheet(isPresented: $detailViewModel.showShareSheet, items: shareItems) { result in
                detailViewModel.handleSharePresentationResult(result)
            }
        )
        .fullScreenCover(isPresented: $detailViewModel.showCameraPicker) {
            ImagePicker(image: $detailViewModel.capturedWalkPhoto, type: .camera)
        }
        .fullScreenCover(isPresented: $detailViewModel.showPhotoLibraryPicker) {
            ImagePicker(image: $detailViewModel.capturedWalkPhoto, type: .photoLibrary)
        }
        .onAppear {
            detailViewModel.bind(context: viewModel)
        }
        .background(Color.appTabScaffoldBackground.ignoresSafeArea())
        .accessibilityIdentifier("screen.walkDetail.sheet")
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

    private var previewSection: some View {
        Image(uiImage: detailViewModel.previewImage(mapCapturedImage: mapImageProvider.capturedImage) ?? UIImage.emptyImg)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .frame(maxHeight: 300)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.appSurfaceStroke, lineWidth: 1)
            )
            .accessibilityIdentifier("walk.detail.previewImage")
            .onAppear {
                guard let polygon = viewModel.polygon.polygon else { return }
                Task {
                    mapImageProvider.captureMapImage(for: polygon)
                }
            }
    }

    private var metricSection: some View {
        HStack {
            SimpleKeyValueView(value: ("영역 넓이", detailViewModel.areaValueText()))
                .onTapGesture { detailViewModel.toggleAreaUnit() }
            Spacer()
            SimpleKeyValueView(value: ("산책 시간", detailViewModel.durationText()))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
    }

    private var shareSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("공유하기")
                .font(.appScaledFont(for: .SemiBold, size: 16, relativeTo: .headline))
                .foregroundStyle(Color.appOnSurfacePrimary)
            Rectangle()
                .foregroundColor(.clear)
                .frame(height: 1)
                .frame(maxWidth: .infinity)
                .background(Color.appSurfaceStroke)
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
            })
            .buttonStyle(.plain)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityIdentifier("walk.detail.capturePhoto")
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
            })
            .buttonStyle(.plain)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityIdentifier("walk.detail.openShareSheet")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("walk.detail.shareSection")
    }

    private var bottomActionSection: some View {
        VStack(spacing: 10) {
            actionButton(title: "저장하기", identifier: "walk.detail.saveToPhotos") {
                _ = detailViewModel.saveShareCardToPhotoLibrary(
                    mapCapturedImage: mapImageProvider.capturedImage,
                    onLoading: { loading.loading() },
                    onFailed: { loading.failed(msg: $0) },
                    onSuccess: { loading.success() }
                )
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    detailViewModel.clearToastMessage()
                }
            }

            actionButton(title: "저장하고 종료", identifier: "walk.detail.confirm", action: handleConfirmWalkEnd)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .safeAreaPadding(.bottom, 8)
        .background(Color.appTabScaffoldBackground.opacity(0.96))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.appSurfaceStroke)
                .frame(height: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("walk.detail.bottomActions")
    }

    /// 산책 종료 상세 시트 하단의 주요 행동 버튼을 공통 스타일과 hit area로 구성합니다.
    /// - Parameters:
    ///   - title: 버튼에 노출할 제목입니다.
    ///   - identifier: UI 테스트와 접근성 추적에 사용할 식별자입니다.
    ///   - action: 버튼 탭 시 실행할 동작입니다.
    /// - Returns: 하단 고정 영역에 맞는 시각 스타일과 접근성 메타데이터를 포함한 버튼입니다.
    private func actionButton(title: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.appScaledFont(for: .SemiBold, size: 16, relativeTo: .body))
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .background(Color(red: 0.99, green: 0.73, blue: 0.73))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(.isButton)
    }
}
//
//#Preview {
//    WalkDetailView(viewModel: .init())
//}
