import SwiftUI
import UIKit
import MapKit

struct WalkListDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State var model: WalkDataModel
    @State private var isMeter: Bool = true
    @State private var showSaveMessage: String? = nil
    @State private var isSystemSharePresented = false
    @State private var shareItems: [Any] = []
    @State private var showShareSheet = false
    @State private var selectedLoc: UUID? = nil
    @State private var sessionMetadata: WalkSessionMetadata? = nil
    @State private var pets: [PetInfo] = []
    @StateObject private var imageRenderer = MapImageProvider()

    private let presentationService: WalkListDetailPresentationServicing = WalkListDetailPresentationService()
    private let outcomeReportInteractionService: WalkOutcomeReportInteracting = WalkOutcomeReportInteractionService()

    private var presentationSnapshot: WalkListDetailPresentationSnapshot {
        presentationService.makeSnapshot(
            model: model,
            sessionMetadata: sessionMetadata,
            pets: pets,
            isMeter: isMeter,
            selectedLocationID: selectedLoc
        )
    }

    var body: some View {
        let polygon = model.toPolygon()

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                WalkListDetailHeroSectionView(
                    hero: presentationSnapshot.hero,
                    metrics: presentationSnapshot.metrics,
                    onToggleAreaUnit: { isMeter.toggle() }
                )

                WalkListDetailOutcomeReportSectionView(
                    explanation: presentationSnapshot.outcomeExplanation,
                    onPresented: {
                        outcomeReportInteractionService.trackPresented(
                            surface: .walkListDetail,
                            context: presentationSnapshot.outcomeExplanation.analyticsContext,
                            userKey: currentMetricUserId()
                        )
                    },
                    onDisclosureToggle: { section, isExpanded in
                        outcomeReportInteractionService.trackDisclosureToggle(
                            section: section,
                            isExpanded: isExpanded,
                            surface: .walkListDetail,
                            context: presentationSnapshot.outcomeExplanation.analyticsContext,
                            userKey: currentMetricUserId()
                        )
                    },
                    onOpenInquiry: openOutcomeReportInquiry
                )

                WalkListDetailMapSectionView(
                    polygon: polygon,
                    selectedLocation: $selectedLoc,
                    selectedPointSummary: presentationSnapshot.selectedPointSummary,
                    hasMapContent: presentationSnapshot.hasMapContent
                )

                WalkListDetailTimelineSectionView(
                    chips: presentationSnapshot.timeline,
                    footnote: presentationSnapshot.timelineFootnote,
                    onSelect: { selectedLoc = $0 }
                )

                WalkListDetailMetaSectionView(rows: presentationSnapshot.metaRows)

                WalkListDetailActionSectionView(
                    onShare: {
                        isSystemSharePresented = false
                        shareItems = prepareShareItems()
                        if shareItems.isEmpty {
                            showToast("공유할 내용을 준비하지 못했어요. 다시 시도해주세요.")
                        } else {
                            isSystemSharePresented = true
                            showShareSheet = true
                        }
                    },
                    onSave: {
                        if let image = imageRenderer.capturedImage {
                            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                            showToast("사진을 저장했어요!")
                        } else {
                            showToast("사진 저장에 실패했어요")
                        }
                    },
                    onDismiss: { dismiss() }
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 28)
        }
        .background(Color.appTabScaffoldBackground.ignoresSafeArea())
        .overlay(alignment: .top) {
            if let msg = showSaveMessage {
                SimpleMessageView(message: msg)
                    .padding(.top, 12)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .topLeading) {
            if isSystemSharePresented {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.black.opacity(0.015))
                    .frame(width: 24, height: 24)
                    .allowsHitTesting(false)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("공유 시트 활성")
                    .accessibilityIdentifier("walklist.detail.share.presenter.active")
                    .padding(.top, 6)
                    .padding(.leading, 6)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showSaveMessage)
        .background(
            ActivityShareSheet(isPresented: $showShareSheet, items: shareItems) { result in
                handleSharePresentationResult(result)
            }
        )
        .navigationTitle("산책 기록")
        .navigationBarTitleDisplayMode(.inline)
        .appTabBarVisibility(.hidden)
        .accessibilityIdentifier("screen.walkListDetail.content")
        .accessibilityValue(isSystemSharePresented ? "share-presented" : "share-idle")
        .onAppear {
            if selectedLoc == nil {
                selectedLoc = model.locations.first?.id
            }
            loadSessionContextIfNeeded()
            captureMapImageIfNeeded()
        }
    }

    /// 저장/공유 결과용 토스트 메시지를 잠시 노출합니다.
    /// - Parameter message: 사용자에게 보여줄 상태 메시지입니다.
    private func showToast(_ message: String) {
        showSaveMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            showSaveMessage = nil
        }
    }

    /// 시스템 공유 시트 presenter가 보고한 이벤트를 상세 화면의 피드백으로 변환합니다.
    /// - Parameter result: 시스템 공유 presenter 결과입니다.
    private func handleSharePresentationResult(_ result: ActivitySharePresentationResult) {
        switch result {
        case .presented:
            isSystemSharePresented = true
        case .completed:
            isSystemSharePresented = false
            showToast("공유를 완료했어요!")
        case .cancelled:
            isSystemSharePresented = false
            showToast("공유를 취소했어요.")
        case .failed:
            isSystemSharePresented = false
            showToast("공유 시트를 열지 못했어요. 다시 시도해주세요.")
        }
    }

    /// 저장된 세션 메타데이터와 반려견 문맥을 현재 화면 상태에 반영합니다.
    private func loadSessionContextIfNeeded() {
        sessionMetadata = WalkSessionMetadataStore.shared.metadata(sessionId: model.id)
        pets = UserdefaultSetting.shared.getValue()?.pet ?? []
    }

    /// 지도 공유 카드 생성용 맵 이미지를 준비합니다.
    private func captureMapImageIfNeeded() {
        guard imageRenderer.capturedImage == nil,
              let polygon = model.toPolygon().polygon else { return }
        imageRenderer.captureMapImage(for: polygon)
    }

    /// 산책 결과 리포트 문의 경로를 열고 관련 interaction metric을 기록합니다.
    private func openOutcomeReportInquiry() {
        guard let url = outcomeReportInteractionService.makeInquiryURL(
            surface: .walkListDetail,
            context: presentationSnapshot.outcomeExplanation.analyticsContext,
            walkCreatedAt: model.createdAt,
            walkDurationText: outcomeMetricValue(id: "duration", fallback: "\(Int(model.walkDuration / 60))분"),
            areaText: outcomeMetricValue(id: "area", fallback: "\(Int(model.walkArea))㎡"),
            pointCount: model.locations.count,
            currentUserId: currentMetricUserId()
        ) else {
            showToast("문의 경로를 준비하지 못했어요. 잠시 후 다시 시도해주세요.")
            return
        }

        openURL(url) { accepted in
            if accepted {
                outcomeReportInteractionService.trackInquiryOpened(
                    surface: .walkListDetail,
                    context: presentationSnapshot.outcomeExplanation.analyticsContext,
                    channel: url.scheme == "mailto" ? "mailto" : "fallback_url",
                    userKey: currentMetricUserId()
                )
            } else {
                showToast("문의 앱을 열지 못했어요. 설정을 확인한 뒤 다시 시도해주세요.")
            }
        }
    }

    /// 결과 리포트 문의 본문에 넣을 핵심 메트릭 문자열을 스냅샷에서 읽습니다.
    /// - Parameters:
    ///   - id: 찾을 메트릭 식별자입니다.
    ///   - fallback: 동일 식별자를 찾지 못했을 때 대신 사용할 문자열입니다.
    /// - Returns: 산책 상세 스냅샷이 계산한 메트릭 문자열입니다.
    private func outcomeMetricValue(id: String, fallback: String) -> String {
        presentationSnapshot.metrics.first(where: { $0.id == id })?.value ?? fallback
    }

    /// 결과 리포트 interaction metric에 사용할 현재 사용자 식별자를 반환합니다.
    /// - Returns: 로그인 사용자 식별자 또는 `nil`입니다.
    private func currentMetricUserId() -> String? {
        UserdefaultSetting.shared.getValue()?.id
    }

    /// 공유 시트에 전달할 요약 텍스트와 카드 이미지를 구성합니다.
    /// - Returns: 시스템 공유 시트로 전달할 아이템 배열입니다.
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
}
