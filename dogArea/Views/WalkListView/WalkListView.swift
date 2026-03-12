//
//  WalkListView.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import SwiftUI
import CoreLocation

struct WalkListView: View {
    @StateObject private var viewModel = WalkListViewModel()
    @EnvironmentObject var authFlow: AuthFlowCoordinator
    @State private var isPresentingUITestDetailPreview = false
    @State private var didPresentUITestDetailPreview = false

    private var topChromeTitle: String {
        if ProcessInfo.processInfo.arguments.contains("-UITest.WalkListHeaderLongSubtitle") {
            return "산책 기록과 월별 흐름"
        }
        return viewModel.overviewModel.title
    }

    private var topChromeSubtitle: String {
        if ProcessInfo.processInfo.arguments.contains("-UITest.WalkListHeaderLongSubtitle") {
            return "선택한 반려견 기록과 달력 흐름을 한 번에 보고 원하는 날짜 기록으로 바로 이동해보세요"
        }
        return viewModel.overviewModel.subtitle
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18, pinnedViews: [.sectionHeaders]) {
                if authFlow.isGuestMode {
                    guestUpgradeCard
                        .padding(.horizontal, 16)
                }

                if let stateCardModel = viewModel.stateCardModel {
                    if stateCardModel.accessibilityIdentifier == "walklist.empty.filtered" {
                        filteredEmptyStateCard
                            .padding(.horizontal, 16)
                    } else if viewModel.calendarModel.isEmptyState == false {
                        emptyHistoryCard
                            .padding(.horizontal, 16)
                    }
                }

                WalkListDashboardHeaderView(
                    overview: viewModel.overviewModel,
                    calendar: viewModel.calendarModel,
                    pets: viewModel.pets,
                    selectedPetId: viewModel.selectedPetId,
                    onSelectPet: viewModel.selectPet(_:),
                    onRestoreSelected: viewModel.showSelectedPetRecords,
                    onPreviousCalendarMonth: viewModel.showPreviousCalendarMonth,
                    onNextCalendarMonth: viewModel.showNextCalendarMonth,
                    onSelectCalendarDate: viewModel.selectCalendarDate(_:),
                    onClearCalendarSelection: viewModel.clearCalendarSelection
                )
                .padding(.horizontal, 16)

                ForEach(viewModel.sectionModels) { section in
                    Section {
                        LazyVStack(spacing: 12) {
                            ForEach(section.items) { item in
                                ZStack(alignment: .topLeading) {
                                    NavigationLink(value: item.walkData) {
                                        WalkListCell(
                                            walkData: item.walkData,
                                            petName: item.petName,
                                            accessibilityIdentifier: item.accessibilityIdentifier
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("walklist.cell")
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    } header: {
                        WalkListSectionHeaderView(model: section)
                            .padding(.horizontal, 16)
                            .background(Color.appTabScaffoldBackground)
                    }
                }
            }
        }
        .refreshable {
            viewModel.fetchModel()
        }
        .appTabRootScrollLayout(
            extraBottomPadding: AppTabLayoutMetrics.defaultScrollExtraBottomPadding,
            topSafeAreaPadding: 0
        )
        .accessibilityIdentifier("screen.walkList.content")
        .nonMapRootPinnedHeaderLayout {
            TitleTextView(
                title: topChromeTitle,
                type: .MediumTitle,
                subTitle: topChromeSubtitle,
                accessibilityIdentifierPrefix: "walklist.header"
            )
            .padding(.horizontal, 16)
        }
        .onAppear {
            viewModel.fetchModel()
            presentWalkDetailPreviewIfNeeded()
        }
        .navigationDestination(for: WalkDataModel.self) { model in
            WalkListDetailView(model: model)
        }
        .navigationDestination(isPresented: $isPresentingUITestDetailPreview) {
            WalkListDetailView(model: Self.makeUITestDetailPreviewModel())
        }
    }

    var guestUpgradeCard: some View {
        let model = WalkListStateCardModel(
            accessibilityIdentifier: "walklist.guest.card",
            badge: "게스트 모드",
            title: "기록은 이 기기에만 저장되고 있어요",
            message: "로그인하면 산책 기록을 백업하고 다른 기기와 동기화할 수 있어요. 지금 보는 목록 구조는 그대로 유지됩니다.",
            footnote: "다음 행동: 로그인 후 기록을 안전하게 보관하세요.",
            primaryActionTitle: "로그인",
            symbolName: "person.crop.circle.badge.plus"
        )
        return WalkListStatusCardView(
            model: model,
            actionAccessibilityIdentifier: "walklist.guest.login"
        ) {
            _ = authFlow.requestAccess(feature: .cloudSync)
        }
    }

    var filteredEmptyStateCard: some View {
        statusCardView(for: viewModel.stateCardModel)
    }

    var emptyHistoryCard: some View {
        statusCardView(for: viewModel.stateCardModel)
    }

    /// 상태 카드 모델에 맞는 액션을 연결한 뷰를 생성합니다.
    /// - Parameter model: 현재 목록 상태를 설명하는 카드 모델입니다.
    /// - Returns: 현재 상태와 액션 wiring이 반영된 카드 뷰입니다.
    @ViewBuilder
    func statusCardView(for model: WalkListStateCardModel?) -> some View {
        if let model {
            WalkListStatusCardView(
                model: model,
                actionAccessibilityIdentifier: model.primaryActionTitle == "전체 기록 보기"
                    ? "walklist.showAllRecords"
                    : nil
            ) {
                if model.primaryActionTitle == "전체 기록 보기" {
                    viewModel.showAllRecordsTemporarily()
                }
            }
        }
    }

    /// UI 테스트 전용 상세 화면 preview route를 한 번만 실행합니다.
    private func presentWalkDetailPreviewIfNeeded() {
        guard didPresentUITestDetailPreview == false,
              Self.shouldPresentUITestDetailPreviewRoute() else { return }
        didPresentUITestDetailPreview = true
        isPresentingUITestDetailPreview = true
    }

    /// 현재 런치 인자에 산책 상세 preview route 요청이 포함되어 있는지 확인합니다.
    /// - Returns: `-UITest.WalkDetailPreviewRoute` 인자가 있으면 `true`입니다.
    private static func shouldPresentUITestDetailPreviewRoute() -> Bool {
        ProcessInfo.processInfo.arguments.contains("-UITest.WalkDetailPreviewRoute")
    }

    /// 산책 상세 UI 회귀 테스트에 사용할 고정 preview 데이터를 생성합니다.
    /// - Returns: 레이아웃과 CTA 위계를 검증할 수 있는 샘플 산책 기록 모델입니다.
    private static func makeUITestDetailPreviewModel() -> WalkDataModel {
        let baseTime = Date(timeIntervalSince1970: 1_772_753_400).timeIntervalSince1970
        let locations: [Location] = [
            .init(coordinate: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780), id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, createdAt: baseTime + 0, pointRole: .mark),
            .init(coordinate: CLLocationCoordinate2D(latitude: 37.5668, longitude: 126.9785), id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, createdAt: baseTime + 180, pointRole: .route),
            .init(coordinate: CLLocationCoordinate2D(latitude: 37.5672, longitude: 126.9792), id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!, createdAt: baseTime + 360, pointRole: .mark),
            .init(coordinate: CLLocationCoordinate2D(latitude: 37.5674, longitude: 126.9798), id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!, createdAt: baseTime + 540, pointRole: .route),
            .init(coordinate: CLLocationCoordinate2D(latitude: 37.5670, longitude: 126.9801), id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!, createdAt: baseTime + 720, pointRole: .mark)
        ]
        let polygon = Polygon(
            locations: locations,
            createdAt: baseTime,
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            walkingTime: 1_420,
            walkingArea: 9_784.92,
            imgData: nil,
            petId: nil
        )
        return WalkDataModel(polygon: polygon)
    }
}

#Preview {
    WalkListView()
}
