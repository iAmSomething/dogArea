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

    @State private var isMeter: Bool = true
    @State private var capturedWalkPhoto: UIImage? = nil
    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false
    @State private var showCameraPicker = false
    @State private var showPhotoLibraryPicker = false
    @State private var toastMessage: String? = nil

    var body: some View {
        VStack {
            Image(uiImage: previewImage ?? UIImage.emptyImg)
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
                SimpleKeyValueView(value: ("영역 넓이", viewModel.calculatedAreaString(areaSize: viewModel.polygon.walkingArea,isPyong: !isMeter)))
                    .onTapGesture {isMeter.toggle()}
                Spacer()
                SimpleKeyValueView(value: ("산책 시간", "\(viewModel.polygon.walkingTime .simpleWalkingTimeInterval)"))
            }.frame(maxWidth: .infinity)
                .padding(.horizontal, 30)
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
                Button(action: {
                    openCameraOrFallback()
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
                    shareItems = prepareShareItems()
                    if shareItems.isEmpty == false {
                        showShareSheet = true
                    }
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
                loading.loading()
                guard let image = buildShareCardImage() else {
                    loading.failed(msg: "이미지 가져오기 실패")
                    return
                }
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                loading.success()
                toastMessage = "저장이 완료되었습니다"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.toastMessage = nil
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
            Button(action: {
                if mapImageProvider.capturedImage == nil {
                    viewModel.walkStatusMessage = "지도 이미지 없이 산책 기록만 저장했습니다."
                }
                viewModel.endWalk(img: mapImageProvider.capturedImage)
                dismiss()
            },
                   label:  {
                Text("확인")
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
            }).frame(maxWidth: .infinity, maxHeight: 50)
                .background(Color(red: 0.99, green: 0.73, blue: 0.73))
                .cornerRadius(15)
                .padding(.horizontal, 70)
        }.overlay(
            Group {
                if let toastMessage {
                    SimpleMessageView(message: toastMessage)
                        .transition(.opacity)
                }
            }.animation(.easeInOut(duration: 0.2), value: toastMessage)
        )
        .sheet(isPresented: $showShareSheet) {
            ActivityShareSheet(items: shareItems) { _, completed, _, _ in
                if completed {
                    toastMessage = "공유를 완료했습니다"
                }
            }
        }
        .fullScreenCover(isPresented: $showCameraPicker) {
            ImagePicker(image: $capturedWalkPhoto, type: .camera)
        }
        .fullScreenCover(isPresented: $showPhotoLibraryPicker) {
            ImagePicker(image: $capturedWalkPhoto, type: .photoLibrary)
        }
    }

    private var previewImage: UIImage? {
        capturedWalkPhoto ?? mapImageProvider.capturedImage
    }

    private func buildShareCardImage() -> UIImage? {
        guard let baseImage = previewImage else { return nil }
        return WalkShareCardTemplateBuilder.build(
            baseImage: baseImage,
            createdAt: viewModel.polygon.createdAt,
            duration: viewModel.polygon.walkingTime,
            areaM2: viewModel.polygon.walkingArea,
            pointCount: viewModel.polygon.locations.count,
            petName: viewModel.currentWalkingPetName
        )
    }

    private func prepareShareItems() -> [Any] {
        let summary = WalkShareSummaryBuilder.build(
            createdAt: viewModel.polygon.createdAt,
            duration: viewModel.polygon.walkingTime,
            areaM2: viewModel.polygon.walkingArea,
            pointCount: viewModel.polygon.locations.count,
            petName: viewModel.currentWalkingPetName
        )
        if let shareCard = buildShareCardImage() {
            return [summary, shareCard]
        }
        return [summary]
    }

    private func openCameraOrFallback() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            showCameraPicker = true
            return
        }
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            toastMessage = "카메라 미지원 환경이라 앨범 선택으로 전환했어요."
            showPhotoLibraryPicker = true
            return
        }
        toastMessage = "이미지 입력을 사용할 수 없는 환경입니다."
    }
}
//
//#Preview {
//    WalkDetailView(viewModel: .init())
//}