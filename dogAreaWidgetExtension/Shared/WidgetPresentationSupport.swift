import WidgetKit
import SwiftUI

enum WidgetSurfaceLayoutTier {
    case compact
    case standard
}

struct WidgetSurfaceLayoutBudget: Equatable {
    let tier: WidgetSurfaceLayoutTier
    let verticalSpacing: CGFloat
    let badgeSpacing: CGFloat
    let maxBadgeCount: Int
    let headlineLineLimit: Int
    let detailLineLimit: Int
    let statusLineLimit: Int
    let ctaLineLimit: Int
    let ctaMinHeight: CGFloat
    let ctaMaxHeight: CGFloat
    let metricTileMinHeight: CGFloat
    let metricTileVerticalPadding: CGFloat
    let metricTileHorizontalPadding: CGFloat

    static let compact = WidgetSurfaceLayoutBudget(
        tier: .compact,
        verticalSpacing: 5,
        badgeSpacing: 5,
        maxBadgeCount: 1,
        headlineLineLimit: 1,
        detailLineLimit: 1,
        statusLineLimit: 1,
        ctaLineLimit: 1,
        ctaMinHeight: 34,
        ctaMaxHeight: 38,
        metricTileMinHeight: 48,
        metricTileVerticalPadding: 6,
        metricTileHorizontalPadding: 8
    )

    static let standard = WidgetSurfaceLayoutBudget(
        tier: .standard,
        verticalSpacing: 8,
        badgeSpacing: 8,
        maxBadgeCount: 2,
        headlineLineLimit: 2,
        detailLineLimit: 2,
        statusLineLimit: 2,
        ctaLineLimit: 2,
        ctaMinHeight: 40,
        ctaMaxHeight: 46,
        metricTileMinHeight: 58,
        metricTileVerticalPadding: 8,
        metricTileHorizontalPadding: 9
    )

    /// WidgetKit family에 대응하는 공통 레이아웃 예산을 반환합니다.
    /// - Parameter family: 현재 위젯이 렌더링되는 family입니다.
    /// - Returns: small은 compact, 그 외 지원 family는 standard 예산을 반환합니다.
    static func resolve(for family: WidgetFamily) -> WidgetSurfaceLayoutBudget {
        family == .systemSmall ? .compact : .standard
    }

    var prefersCompactFormatting: Bool {
        tier == .compact
    }

    /// 현재 family 예산에 맞는 경과 시간 문자열을 생성합니다.
    /// - Parameter elapsedSeconds: 경과 시간(초)입니다.
    /// - Returns: compact family면 축약 문자열을, 아니면 전체 시간 문자열을 반환합니다.
    func elapsedText(_ elapsedSeconds: Int) -> String {
        prefersCompactFormatting
            ? WidgetFormatting.formattedElapsedCompact(elapsedSeconds)
            : WidgetFormatting.formattedElapsed(elapsedSeconds)
    }

    /// 현재 family 예산에 맞는 면적 문자열을 생성합니다.
    /// - Parameter areaM2: 원본 면적(`m²`)입니다.
    /// - Returns: compact family면 축약 면적 문자열을, 아니면 기본 면적 문자열을 반환합니다.
    func areaText(_ areaM2: Double) -> String {
        prefersCompactFormatting
            ? WidgetFormatting.formattedCompactArea(areaM2)
            : WidgetFormatting.formattedArea(areaM2)
    }
}

struct WidgetBadgeDescriptor: Identifiable {
    let id: String
    let title: String
    let color: Color

    init(id: String? = nil, title: String, color: Color) {
        self.id = id ?? title
        self.title = title
        self.color = color
    }
}

struct WidgetStatusBadge: View {
    let title: String
    let color: Color
    var budget: WidgetSurfaceLayoutBudget = .standard

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, budget.prefersCompactFormatting ? 7 : 8)
            .padding(.vertical, budget.prefersCompactFormatting ? 3 : 4)
            .background(color)
            .clipShape(Capsule())
    }
}

struct WidgetBadgeStripView: View {
    let badges: [WidgetBadgeDescriptor]
    let budget: WidgetSurfaceLayoutBudget

    private var visibleBadges: [WidgetBadgeDescriptor] {
        Array(badges.prefix(budget.maxBadgeCount))
    }

    private var overflowCount: Int {
        max(0, badges.count - budget.maxBadgeCount)
    }

    var body: some View {
        HStack(spacing: budget.badgeSpacing) {
            ForEach(visibleBadges) { badge in
                WidgetStatusBadge(
                    title: badge.title,
                    color: badge.color,
                    budget: budget
                )
            }
            if overflowCount > 0 {
                WidgetStatusBadge(
                    title: "+\(overflowCount)",
                    color: Color.secondary.opacity(0.14),
                    budget: budget
                )
            }
        }
    }
}

enum WidgetStateTaxonomy: String, CaseIterable {
    case guest = "guest"
    case empty = "empty"
    case offline = "offline"
    case syncDelayed = "sync_delayed"
}

enum WidgetStateSurfaceContext: Equatable {
    case territory
    case hotspot(radiusPreset: HotspotWidgetRadiusPreset)
    case questRival
}

struct WidgetStateCTAContent: Equatable {
    let title: String
    let systemImage: String
    let accessibilityLabel: String
    let accessibilityHint: String
}

struct WidgetStatePresentationContent {
    let badgeTitle: String
    let badgeColor: Color
    let headline: String
    let detail: String
    let cta: WidgetStateCTAContent
}

enum WidgetStatePresentationGuide {
    /// 위젯 공통 상태 taxonomy와 표면 종류에 맞는 카피/CTA 구성을 반환합니다.
    /// - Parameters:
    ///   - taxonomy: 위젯 상태 taxonomy입니다.
    ///   - surface: 카피를 적용할 위젯 표면 종류입니다.
    ///   - fallbackMessage: 서버/스냅샷이 제공한 상태 설명이 있으면 우선 반영할 보조 문구입니다.
    /// - Returns: 상태 배지, 설명, CTA가 정리된 공통 프레젠테이션 값입니다.
    static func presentation(
        for taxonomy: WidgetStateTaxonomy,
        surface: WidgetStateSurfaceContext,
        fallbackMessage: String? = nil
    ) -> WidgetStatePresentationContent {
        let resolvedFallback = fallbackMessage?.trimmingCharacters(in: .whitespacesAndNewlines)

        switch taxonomy {
        case .guest:
            switch surface {
            case .territory:
                return .init(
                    badgeTitle: "로그인 필요",
                    badgeColor: .orange.opacity(0.20),
                    headline: "영역 현황을 보려면 로그인해 주세요",
                    detail: "오늘/주간 지표와 다음 목표를 위젯에서 이어서 볼 수 있어요.",
                    cta: signInCTA(surfaceName: "영역 현황")
                )
            case let .hotspot(radiusPreset):
                return .init(
                    badgeTitle: "로그인 필요",
                    badgeColor: .orange.opacity(0.20),
                    headline: "\(radiusPreset.shortLabel) 핫스팟을 보려면 로그인해 주세요",
                    detail: "익명 핫스팟 단계는 로그인 후 활성화됩니다.",
                    cta: signInCTA(surfaceName: "익명 핫스팟")
                )
            case .questRival:
                return .init(
                    badgeTitle: "로그인 필요",
                    badgeColor: .orange.opacity(0.20),
                    headline: "퀘스트/라이벌을 보려면 로그인해 주세요",
                    detail: "오늘의 퀘스트 진행률과 라이벌 순위를 위젯에서 이어서 확인할 수 있어요.",
                    cta: signInCTA(surfaceName: "퀘스트/라이벌")
                )
            }
        case .empty:
            switch surface {
            case .territory:
                return .init(
                    badgeTitle: "첫 행동",
                    badgeColor: .blue.opacity(0.18),
                    headline: "첫 산책을 시작해 보세요",
                    detail: resolvedFallback ?? "첫 타일을 점령하면 다음 목표와 남은 면적을 바로 보여드릴게요.",
                    cta: firstActionCTA(
                        title: "앱에서 첫 산책 시작",
                        systemImage: "figure.walk",
                        accessibilityLabel: "앱에서 첫 산책 시작",
                        accessibilityHint: "앱으로 이동해 첫 타일 점령을 시작합니다."
                    )
                )
            case .hotspot:
                return .init(
                    badgeTitle: "첫 행동",
                    badgeColor: .blue.opacity(0.18),
                    headline: "익명 공유를 시작해 보세요",
                    detail: resolvedFallback ?? "공유가 시작되면 주변 익명 신호 단계가 위젯에 표시됩니다.",
                    cta: firstActionCTA(
                        title: "앱에서 익명 공유 시작",
                        systemImage: "antenna.radiowaves.left.and.right",
                        accessibilityLabel: "앱에서 익명 공유 시작",
                        accessibilityHint: "앱으로 이동해 익명 위치 공유를 시작합니다."
                    )
                )
            case .questRival:
                return .init(
                    badgeTitle: "첫 행동",
                    badgeColor: .blue.opacity(0.18),
                    headline: "오늘의 퀘스트를 시작해 보세요",
                    detail: resolvedFallback ?? "첫 행동이 기록되면 진행률과 라이벌 순위를 바로 보여드릴게요.",
                    cta: firstActionCTA(
                        title: "앱에서 퀘스트 시작",
                        systemImage: "list.bullet.rectangle.portrait",
                        accessibilityLabel: "앱에서 퀘스트 시작",
                        accessibilityHint: "앱으로 이동해 오늘의 퀘스트를 확인합니다."
                    )
                )
            }
        case .offline:
            return .init(
                badgeTitle: "오프라인",
                badgeColor: .orange.opacity(0.20),
                headline: "마지막 동기화 내용을 보여주고 있어요",
                detail: resolvedFallback ?? "연결이 복구되면 위젯이 자동으로 최신 상태로 돌아옵니다.",
                cta: waitRecoveryCTA()
            )
        case .syncDelayed:
            return .init(
                badgeTitle: "지연",
                badgeColor: .red.opacity(0.18),
                headline: "최신 상태 반영이 늦어지고 있어요",
                detail: resolvedFallback ?? "앱을 열어 최신 상태를 다시 불러와 주세요.",
                cta: refreshInAppCTA()
            )
        }
    }

    /// 로그인 유도 상태에서 사용할 공통 CTA를 생성합니다.
    /// - Parameter surfaceName: 로그인 후 확인할 위젯 표면 이름입니다.
    /// - Returns: 로그인 유도용 CTA 문구와 접근성 메타데이터입니다.
    private static func signInCTA(surfaceName: String) -> WidgetStateCTAContent {
        .init(
            title: "앱에서 로그인",
            systemImage: "person.crop.circle.badge.checkmark",
            accessibilityLabel: "앱에서 로그인",
            accessibilityHint: "\(surfaceName) 위젯을 쓰려면 로그인해야 합니다."
        )
    }

    /// 첫 행동 유도 상태에서 사용할 공통 CTA를 생성합니다.
    /// - Parameters:
    ///   - title: 사용자에게 노출할 CTA 제목입니다.
    ///   - systemImage: CTA에 함께 표시할 SF Symbol 이름입니다.
    ///   - accessibilityLabel: 접근성에 읽힐 CTA 라벨입니다.
    ///   - accessibilityHint: 접근성 힌트입니다.
    /// - Returns: 첫 행동 유도용 CTA 문구와 접근성 메타데이터입니다.
    private static func firstActionCTA(
        title: String,
        systemImage: String,
        accessibilityLabel: String,
        accessibilityHint: String
    ) -> WidgetStateCTAContent {
        .init(
            title: title,
            systemImage: systemImage,
            accessibilityLabel: accessibilityLabel,
            accessibilityHint: accessibilityHint
        )
    }

    /// 오프라인 복구 대기 상태에서 사용할 공통 CTA를 생성합니다.
    /// - Returns: 연결 복구 대기 상태를 설명하는 CTA 문구와 접근성 메타데이터입니다.
    private static func waitRecoveryCTA() -> WidgetStateCTAContent {
        .init(
            title: "연결 복구 대기 중",
            systemImage: "wifi.slash",
            accessibilityLabel: "연결 복구 대기 중",
            accessibilityHint: "네트워크가 복구되면 위젯이 자동으로 다시 갱신됩니다."
        )
    }

    /// 최신화 지연 상태에서 사용할 공통 CTA를 생성합니다.
    /// - Returns: 앱 재진입 최신화 유도용 CTA 문구와 접근성 메타데이터입니다.
    private static func refreshInAppCTA() -> WidgetStateCTAContent {
        .init(
            title: "앱에서 최신 상태 확인",
            systemImage: "arrow.clockwise",
            accessibilityLabel: "앱에서 최신 상태 확인",
            accessibilityHint: "앱으로 이동해 최신 상태를 다시 불러옵니다."
        )
    }
}

struct WidgetStateCTAView: View {
    let cta: WidgetStateCTAContent
    var budget: WidgetSurfaceLayoutBudget = .standard
    var tint: Color = .orange

    var body: some View {
        Label(cta.title, systemImage: cta.systemImage)
            .font(budget.prefersCompactFormatting ? .caption2.weight(.semibold) : .caption.weight(.semibold))
            .lineLimit(budget.ctaLineLimit)
            .minimumScaleFactor(0.82)
            .frame(
                maxWidth: .infinity,
                minHeight: budget.ctaMinHeight,
                maxHeight: budget.ctaMaxHeight,
                alignment: .leading
            )
            .foregroundStyle(tint)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(cta.accessibilityLabel)
            .accessibilityHint(cta.accessibilityHint)
    }
}

struct WidgetMetricTileView: View {
    let title: String
    let value: String
    let tint: Color
    let budget: WidgetSurfaceLayoutBudget

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, minHeight: budget.metricTileMinHeight, alignment: .leading)
        .padding(.vertical, budget.metricTileVerticalPadding)
        .padding(.horizontal, budget.metricTileHorizontalPadding)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

enum WidgetFormatting {
    /// 경과 시간을 `HH:MM:SS` 형식으로 변환합니다.
    /// - Parameter elapsedSeconds: 변환할 경과 시간(초)입니다.
    /// - Returns: 위젯 표시용 시간 문자열입니다.
    static func formattedElapsed(_ elapsedSeconds: Int) -> String {
        let total = max(0, elapsedSeconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    /// 경과 시간을 compact/minimal 표면에서 쓰기 좋은 축약 문자열로 변환합니다.
    /// - Parameter elapsedSeconds: 변환할 경과 시간(초)입니다.
    /// - Returns: `59m`, `2h`, `45s` 형식의 축약 시간 문자열입니다.
    static func formattedElapsedCompact(_ elapsedSeconds: Int) -> String {
        let total = max(0, elapsedSeconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return "\(hours)h"
        }
        if minutes > 0 {
            return "\(minutes)m"
        }
        return "\(seconds)s"
    }

    /// 유닉스 타임스탬프를 위젯 표시용 `HH:mm` 문자열로 변환합니다.
    /// - Parameter timestamp: 변환할 유닉스 초 단위 타임스탬프입니다.
    /// - Returns: 사용자 로캘 기준의 시:분 문자열입니다.
    static func formattedTime(timestamp: TimeInterval) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("HHmm")
        return formatter.string(from: Date(timeIntervalSince1970: timestamp))
    }

    /// 제곱미터 면적을 위젯 표시용 문자열로 변환합니다.
    /// - Parameter areaM2: 변환할 원본 면적(`m²`)입니다.
    /// - Returns: `㎡ / 만 ㎡ / k㎡` 규칙이 반영된 위젯 표시 문자열입니다.
    static func formattedArea(_ areaM2: Double) -> String {
        let area = max(0, areaM2)
        if area > 100_000 {
            return String(format: "%.2f", area / 1_000_000) + "k㎡"
        }
        if area > 10_000 {
            return String(format: "%.2f", area / 10_000) + "만 ㎡"
        }
        return String(format: "%.2f", area) + "㎡"
    }

    /// 제곱미터 면적을 compact 표면 폭에 맞는 짧은 문자열로 변환합니다.
    /// - Parameter areaM2: 변환할 원본 면적(`m²`)입니다.
    /// - Returns: `42㎡`, `1.2k㎡`, `0.8만㎡` 형식의 축약 면적 문자열입니다.
    static func formattedCompactArea(_ areaM2: Double) -> String {
        let area = max(0, areaM2)
        if area >= 100_000 {
            return String(format: "%.1f", area / 1_000_000) + "k㎡"
        }
        if area >= 10_000 {
            return String(format: "%.1f", area / 10_000) + "만㎡"
        }
        if area >= 100 {
            return "\(Int(area.rounded()))㎡"
        }
        return String(format: "%.1f", area) + "㎡"
    }

    /// 진행률 비율을 위젯 표시용 백분율 문자열로 변환합니다.
    /// - Parameter ratio: `0...1` 범위로 정규화된 진행률입니다.
    /// - Returns: 퍼센트 단위가 포함된 위젯 표시 문자열입니다.
    static func formattedPercent(_ ratio: Double) -> String {
        let normalized = min(1.0, max(0.0, ratio))
        return "\(Int((normalized * 100).rounded()))%"
    }

    /// 퀘스트/행동 부족분 실수 값을 위젯 표시용 축약 문자열로 변환합니다.
    /// - Parameter value: 남은 진행량 실수 값입니다.
    /// - Returns: 정수면 정수로, 아니면 소수 첫째 자리까지 포함한 문자열입니다.
    static func formattedProgressDelta(_ value: Double) -> String {
        let clamped = max(0.0, value)
        if abs(clamped.rounded() - clamped) < 0.001 {
            return String(Int(clamped.rounded()))
        }
        return String(format: "%.1f", clamped)
    }
}
