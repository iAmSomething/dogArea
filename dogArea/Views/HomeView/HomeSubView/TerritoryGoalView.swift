import SwiftUI

struct TerritoryGoalView: View {
    @ObservedObject var viewModel: TerritoryGoalViewModel
    @ObservedObject private var tabStatus = TabAppear.shared

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                headerSection
                overviewCard
                insightSection
                recentSection
                emptyHintCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .background(Color.appTabScaffoldBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("영역 목표 상세")
        .onAppear {
            tabStatus.hide()
            viewModel.refresh()
        }
        .onDisappear {
            tabStatus.appear()
        }
        .refreshable {
            viewModel.refresh()
        }
    }

    private var insightSection: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("최근 정복")
                    .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                Text("\(viewModel.recentAreas.count)개")
                    .font(.appScaledFont(for: .SemiBold, size: 26, relativeTo: .title3))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.appDynamicHex(light: 0xFFFFFF, dark: 0x1E293B))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("다음 목표까지")
                    .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
                Text(viewModel.remainingAreaText)
                    .font(.appScaledFont(for: .SemiBold, size: 26, relativeTo: .title3))
                    .foregroundStyle(Color.appDynamicHex(light: 0xF59E0B, dark: 0xFACC15))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.appDynamicHex(light: 0xFFFFFF, dark: 0x1E293B))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155), lineWidth: 1)
            )
        }
    }

    /// 상단 타이틀/서브타이틀/반려견 배지를 렌더링합니다.
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Territory Goal Tracker")
                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                .foregroundStyle(Color.appDynamicHex(light: 0xCBD5E1, dark: 0x64748B))
            Text(viewModel.title)
                .font(.appScaledFont(for: .SemiBold, size: 44, relativeTo: .title2))
                .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
            Text(viewModel.subtitle)
                .font(.appScaledFont(for: .Regular, size: 16, relativeTo: .subheadline))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
            Text(viewModel.selectedPetBadgeText)
                .font(.appScaledFont(for: .SemiBold, size: 12, relativeTo: .caption))
                .foregroundStyle(Color.appDynamicHex(light: 0xF59E0B, dark: 0xFACC15))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appDynamicHex(light: 0xFEF3C7, dark: 0x78350F, alpha: 0.3))
                .cornerRadius(10)
            Text("비교군/최근 정복 이력/다음 목표까지 남은 면적을 한 번에 확인할 수 있어요.")
                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0xCBD5E1))
        }
    }

    /// 목표 요약 카드(현재/다음/진행률)를 렌더링합니다.
    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("영역 목표 트래커")
                        .font(.appScaledFont(for: .SemiBold, size: 30, relativeTo: .title3))
                        .foregroundStyle(Color.appDynamicHex(light: 0x7C2D12, dark: 0xFED7AA))
                    Text(viewModel.areaSourceText)
                        .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption))
                        .foregroundStyle(Color.appDynamicHex(light: 0xC2410C, dark: 0xFDBA74))
                }
                Spacer()
                NavigationLink(destination: AreaDetailView(viewModel: viewModel.homeViewModel)) {
                    Text("비교군 보러\n가기 >")
                        .font(.appScaledFont(for: .SemiBold, size: 12, relativeTo: .caption))
                        .foregroundStyle(Color.appDynamicHex(light: 0xC2410C, dark: 0xFDBA74))
                        .multilineTextAlignment(.trailing)
                        .frame(minHeight: 44)
                }
            }

            HStack(alignment: .top, spacing: 16) {
                metricColumn(title: "현재 영역", value: viewModel.currentAreaText, detail: viewModel.title)
                metricColumn(title: "다음 목표", value: viewModel.nextGoalNameText, detail: viewModel.nextGoalAreaText)
            }

            HStack(alignment: .bottom) {
                Text("남은 면적: \(viewModel.remainingAreaText)")
                    .font(.appScaledFont(for: .SemiBold, size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0x92400E, dark: 0xFED7AA))
                Spacer()
                Text(viewModel.progressPercentText)
                    .font(.appScaledFont(for: .SemiBold, size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0xF59E0B, dark: 0xFACC15))
            }

            overviewProgressBar(progress: viewModel.progressRatio)
                .accessibilityLabel("목표 진행률")
                .accessibilityValue(viewModel.progressPercentText)

            Text("목표까지 아주 조금 남았어요! 한 번만 더 산책해볼까요?")
                .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption2))
                .foregroundStyle(Color.appDynamicHex(light: 0xC2410C, dark: 0xFDBA74))
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.appDynamicHex(light: 0xFFF7EB, dark: 0x431407, alpha: 0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.appDynamicHex(light: 0xFED7AA, dark: 0x7C2D12), lineWidth: 1)
        )
    }

    /// 목표 카드 내부의 지표 컬럼을 렌더링합니다.
    /// - Parameters:
    ///   - title: 지표 제목입니다.
    ///   - value: 강조 값입니다.
    ///   - detail: 보조 설명입니다.
    /// - Returns: 지표 컬럼 뷰입니다.
    private func metricColumn(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .caption))
                .foregroundStyle(Color.appDynamicHex(light: 0xC2410C, dark: 0xFDBA74))
            Text(value)
                .font(.appScaledFont(for: .SemiBold, size: 40, relativeTo: .title3))
                .foregroundStyle(Color.appDynamicHex(light: 0x7C2D12, dark: 0xFEF3C7))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail)
                .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption2))
                .foregroundStyle(Color.appDynamicHex(light: 0x92400E, dark: 0xFDBA74))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 최근 정복한 영역 리스트를 렌더링합니다.
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("최근 정복한 영역")
                    .font(.appScaledFont(for: .SemiBold, size: 34, relativeTo: .title2))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                Spacer()
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0xCBD5E1))
            }

            ForEach(Array(viewModel.recentAreas.enumerated()), id: \.offset) { index, item in
                recentRow(item: item, isNew: index == 0, colorSeed: index)
            }
        }
    }

    /// 최근 정복 리스트의 단일 행을 렌더링합니다.
    /// - Parameters:
    ///   - item: 표시할 영역 DTO입니다.
    ///   - isNew: 최신 항목 여부입니다.
    ///   - colorSeed: 썸네일 색상 시드 인덱스입니다.
    /// - Returns: 최근 정복 행 뷰입니다.
    private func recentRow(item: AreaMeterDTO, isNew: Bool, colorSeed: Int) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(thumbnailColor(for: colorSeed))
                .frame(width: 54, height: 54)
                .overlay {
                    Image(systemName: "photo")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.9))
                }
            VStack(alignment: .leading, spacing: 3) {
                Text(item.areaName)
                    .font(.appScaledFont(for: .SemiBold, size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Color.appDynamicHex(light: 0x0F172A, dark: 0xF8FAFC))
                    .lineLimit(1)
                Text(item.createdAt.createdAtTimeDescriptionSimple + " · +\(item.area.calculatedAreaString)")
                    .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0x64748B, dark: 0x94A3B8))
                    .lineLimit(1)
            }
            Spacer()
            if isNew {
                Text("NEW")
                    .font(.appScaledFont(for: .SemiBold, size: 10, relativeTo: .caption2))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.appDynamicHex(light: 0xDCFCE7, dark: 0x166534))
                    .foregroundStyle(Color.appDynamicHex(light: 0x16A34A, dark: 0xDCFCE7))
                    .cornerRadius(9)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appDynamicHex(light: 0xCBD5E1, dark: 0x64748B))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Color.appDynamicHex(light: 0xFFFFFF, dark: 0x1E293B))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155), lineWidth: 1)
        )
        .cornerRadius(14)
    }

    /// 최근 정복 섹션 하단의 빈 상태 힌트 카드를 렌더링합니다.
    private var emptyHintCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.walk")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.appDynamicHex(light: 0xEAB308, dark: 0xFACC15))
            Text("산책을 통해 영역을 넓혀봐요!")
                .font(.appScaledFont(for: .SemiBold, size: 14, relativeTo: .subheadline))
                .foregroundStyle(Color.appDynamicHex(light: 0x334155, dark: 0xCBD5E1))
            Text("새로운 장소를 갈 때마다 영역이 확장됩니다.")
                .font(.appScaledFont(for: .Regular, size: 12, relativeTo: .footnote))
                .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0x64748B))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    Color.appDynamicHex(light: 0xEAB308, dark: 0xFACC15, alpha: 0.35),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 2])
                )
        )
    }

    /// 영역 목표 카드에 표시할 진행바를 렌더링합니다.
    /// - Parameter progress: 0~1 범위의 진행률입니다.
    /// - Returns: 목표 진행률 바 뷰입니다.
    private func overviewProgressBar(progress: Double) -> some View {
        GeometryReader { proxy in
            let clamped = min(1.0, max(0.0, progress))
            let width = max(10, proxy.size.width * clamped)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.appDynamicHex(light: 0xFED7AA, dark: 0x7C2D12, alpha: 0.35))
                Capsule()
                    .fill(Color.appDynamicHex(light: 0xEAB308, dark: 0xFACC15))
                    .frame(width: width)
            }
        }
        .frame(height: 8)
    }

    /// 최근 정복 썸네일에 사용할 인덱스 기반 색상을 반환합니다.
    /// - Parameter index: 리스트 인덱스입니다.
    /// - Returns: 지정 인덱스에 대응하는 썸네일 배경색입니다.
    private func thumbnailColor(for index: Int) -> Color {
        let palette: [Color] = [
            Color.appDynamicHex(light: 0x10B981, dark: 0x047857),
            Color.appDynamicHex(light: 0x94A3B8, dark: 0x475569),
            Color.appDynamicHex(light: 0x3B82F6, dark: 0x1D4ED8)
        ]
        return palette[index % palette.count]
    }
}
