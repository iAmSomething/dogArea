import SwiftUI

struct RecoveryActionBanner: View {
    let issue: RecoveryIssue
    let onPrimary: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(issue.title)
                .font(.appFont(for: .SemiBold, size: 13))
            Text(issue.message)
                .font(.appFont(for: .Light, size: 11))
                .foregroundStyle(Color.appTextDarkGray)
            HStack(spacing: 10) {
                Button(issue.primaryButtonTitle) {
                    onPrimary()
                }
                .font(.appFont(for: .SemiBold, size: 11))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appYellow)
                .cornerRadius(8)

                Button("닫기") {
                    onDismiss()
                }
                .font(.appFont(for: .SemiBold, size: 11))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appYellowPale)
                .cornerRadius(8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.95))
        .cornerRadius(12)
        .padding(.horizontal, 12)
    }
}

struct SyncOutboxRecoveryBanner: View {
    let overview: SyncOutboxPermanentFailureOverview
    let onRebuild: (() -> Void)?
    let onArchive: (() -> Void)?
    let onContactSupport: (() -> Void)?
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(overview.title)
                .font(.appFont(for: .SemiBold, size: 13))
                .foregroundStyle(MapChromePalette.primaryText)
                .accessibilityIdentifier("map.syncOutbox.recovery.title")

            Text(overview.message)
                .font(.appFont(for: .Light, size: 11))
                .foregroundStyle(MapChromePalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if overview.detailLines.isEmpty == false {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(overview.detailLines.enumerated()), id: \.offset) { index, line in
                        HStack(alignment: .top, spacing: 6) {
                            Text("-")
                            Text(line)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .font(.appFont(for: .Light, size: 11))
                        .foregroundStyle(MapChromePalette.secondaryText)
                        .accessibilityIdentifier("map.syncOutbox.recovery.detail.\(index)")
                    }
                }
            }

            VStack(spacing: 8) {
                if let onRebuild {
                    Button("복구 다시 만들기") {
                        onRebuild()
                    }
                    .font(.appFont(for: .SemiBold, size: 12))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.appGreen)
                    .cornerRadius(10)
                    .accessibilityIdentifier("map.syncOutbox.rebuild")
                }

                if let onArchive {
                    Button("동기화 목록 정리") {
                        onArchive()
                    }
                    .font(.appFont(for: .SemiBold, size: 12))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.appYellow)
                    .cornerRadius(10)
                    .accessibilityIdentifier("map.syncOutbox.archive")
                }

                HStack(spacing: 8) {
                    if let onContactSupport {
                        Button("문의 메일") {
                            onContactSupport()
                        }
                        .font(.appFont(for: .SemiBold, size: 12))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.appTextLightGray.opacity(0.85))
                        .cornerRadius(10)
                        .accessibilityIdentifier("map.syncOutbox.contactSupport")
                    }

                    Button("나중에 보기") {
                        onDismiss()
                    }
                    .font(.appFont(for: .SemiBold, size: 12))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.appYellowPale)
                    .cornerRadius(10)
                    .accessibilityIdentifier("map.syncOutbox.dismiss")
                }
            }
        }
        .padding(10)
        .mapChromeSurface()
        .accessibilityIdentifier("map.syncOutbox.recoveryBanner")
    }
}
