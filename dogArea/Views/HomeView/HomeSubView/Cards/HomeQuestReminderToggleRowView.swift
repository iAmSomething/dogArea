import SwiftUI

struct HomeQuestReminderToggleRowView: View {
    @Binding var isEnabled: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("퀘스트 리마인드")
                    .font(.appScaledFont(for: .SemiBold, size: 14, relativeTo: .subheadline))
                Text("매일 20:00 · 하루 최대 1회")
                    .font(.appScaledFont(for: .Regular, size: 11, relativeTo: .caption))
                    .foregroundStyle(Color.appDynamicHex(light: 0x94A3B8, dark: 0xCBD5E1))
            }
            Spacer()
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .tint(Color.appDynamicHex(light: 0xF59E0B, dark: 0xEAB308))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.appDynamicHex(light: 0xF8FAFC, dark: 0x1E293B))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.appDynamicHex(light: 0xE2E8F0, dark: 0x334155), lineWidth: 1)
        )
    }
}
