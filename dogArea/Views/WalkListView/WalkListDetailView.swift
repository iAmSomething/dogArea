//
//  WalkListDetailView.swift
//  dogArea
//
//  Created by 김태훈 on 11/13/23.
//

import SwiftUI
import MapKit
struct WalkListDetailView: View {
    @Environment(\.dismiss) var dismiss
    @State var model: WalkDataModel
    @State private var isMeter: Bool = true
    @State private var showSaveMessage: String? = nil
    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false
    @State private var selectedLoc: UUID? = nil
    @State private var sessionMetadata: WalkSessionMetadata? = nil
    @StateObject var imageRenderer = MapImageProvider()
    var body: some View {
        let tempPolygon = model.toPolygon()
        ScrollView{
            VStack {
                HStack {
                    Text("산책한 영역")
                        .padding(.horizontal, 20)
                        .font(.appFont(for: .SemiBold, size: 20))
                    Spacer()
                }.frame(maxWidth: .infinity)
                UnderLine()
                SimpleMapView(polygon: tempPolygon, selectedLocation: $selectedLoc)
                    .frame(maxWidth: .infinity , minHeight: screenSize.width - 40, maxHeight: .infinity)
                    .cornerRadius(5)
                    .padding(.horizontal, 20)
                    .padding(.bottom,20)
                HStack {
                    SimpleKeyValueView(value: ("영역 넓이","\(calculatedAreaString(areaSize: model.walkArea , isPyong : !isMeter))"))
                        .onTapGesture {isMeter.toggle()}
                    Spacer()
                    SimpleKeyValueView(value: ("산책 시간","\(model.walkDuration.simpleWalkingTimeInterval)"))
                }.frame(maxWidth: .infinity)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 20)
                if let sessionMetadata {
                    HStack {
                        Text("종료 사유: \(endReasonText(sessionMetadata.endReason)) · 종료 시각: \(sessionMetadata.endedAt.createdAtTimeDescription)")
                            .font(.appFont(for: .Light, size: 12))
                            .foregroundStyle(Color.appTextDarkGray)
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                }
                VStack{
                    HStack {
                        Text("영역 표시한 곳")
                            .padding(.horizontal, 20)
                            .font(.appFont(for: .SemiBold, size: 20))

                        Spacer()
                    }.frame(maxWidth: .infinity)
                    UnderLine()
                    ScrollView(.horizontal) {
                        LazyHGrid(rows: [GridItem(.fixed(32))] , alignment: .top){
                            ForEach(model.locations) { loc in
                                Text("\(loc.createdAt.createdAtTimeHHMM)")
                                    .font(.appFont(for: .Medium, size: 14))
                                    .padding(5)
                                    .foregroundStyle(Color.appTextDarkGray)
                                    .background(self.selectedLoc == loc.id ? Color.appPeach : Color.appYellowPale)
                                    .cornerRadius(5)
                                    .onTapGesture {
                                        self.selectedLoc = loc.id
                                    }
                            }
                        }
                    }.frame(height: 60)
                        .padding(.horizontal, 20)
                }
                Button(action: {
                    shareItems = prepareShareItems()
                    if shareItems.isEmpty == false {
                        showShareSheet = true
                    }
                }, label:  {
                    Text("공유하기")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .foregroundStyle(.black)
                }).frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color(red: 0.99, green: 0.73, blue: 0.73))
                    .cornerRadius(15)
                    .padding(.horizontal, 70)
                Button(action: {
                    if let img = imageRenderer.capturedImage {
                        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                        showSaveMessage = "사진을 저장했어요!"
                    } else {
                        showSaveMessage = "사진 저장에 실패했어요"
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        showSaveMessage = nil
                    }
                },
                       label:  {
                    Text("사진으로 저장하기")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .foregroundStyle(.black)
                }).frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color(red: 0.99, green: 0.73, blue: 0.73))
                    .cornerRadius(15)
                    .padding(.horizontal, 70)
                Spacer()
                Button(action: {
                    dismiss()
                },
                       label:  {
                    Text("확인")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .foregroundStyle(.black)
                }).frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color(red: 0.99, green: 0.73, blue: 0.73))
                    .cornerRadius(15)
                    .padding(.horizontal, 70)
            }.overlay(
                Group {
                    if let msg = showSaveMessage {
                        SimpleMessageView(message: msg)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: showSaveMessage)
            ).navigationBarBackButtonHidden()
        }.padding(.top, 20)
        .sheet(isPresented: $showShareSheet) {
            ActivityShareSheet(items: shareItems) { _, completed, _, _ in
                if completed {
                    showSaveMessage = "공유를 완료했어요!"
                }
            }
        }
        .onAppear {
            if let polygon = model.toPolygon().polygon {
                imageRenderer.captureMapImage(for: polygon)
            }
            sessionMetadata = WalkSessionMetadataStore.shared.metadata(sessionId: model.id)
        }
        .safeAreaPadding(.top, 20)
        .appTabBarVisibility(.hidden)

    }
    private func endReasonText(_ reason: WalkSessionEndReason) -> String {
        switch reason {
        case .manual: return "수동 종료"
        case .autoInactive: return "무이동 자동 종료"
        case .autoTimeout: return "시간 제한 자동 종료"
        case .recoveryEstimated: return "복구 추정 종료"
        }
    }

    private func prepareShareItems() -> [Any] {
        let summary = WalkShareSummaryBuilder.build(
            createdAt: model.createdAt,
            duration: model.walkDuration,
            areaM2: model.walkArea,
            pointCount: model.locations.count,
            petName: nil
        )
        if let image = imageRenderer.capturedImage ?? model.image {
            let shareCard = WalkShareCardTemplateBuilder.build(
                baseImage: image,
                createdAt: model.createdAt,
                duration: model.walkDuration,
                areaM2: model.walkArea,
                pointCount: model.locations.count,
                petName: nil
            )
            return [summary, shareCard]
        }
        return [summary]
    }

    func calculatedAreaString(areaSize: Double , isPyong: Bool = false) -> String {
        var str = String(format: "%.2f" , areaSize) + "㎡"
        if areaSize > 10000.0 {
            str = String(format: "%.2f" , areaSize/10000) + "만 ㎡"
        }
        if areaSize > 100000.0 {
            str = String(format: "%.2f" , areaSize/1000000) + "k㎡"
        }
        if isPyong {
            if areaSize/3.3 > 10000 {
                str = String(format: "%.1f" , areaSize/33333) + "만 평"

            } else {
                str = String(format: "%.1f" , areaSize/3.3) + "평"
            }
        }
        return str
    }
}
