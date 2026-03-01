import SwiftUI

struct AreaDetailListHeaderView: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        if let next = viewModel.nearlistMore() {
            VStack {
                HStack {
                    Text("다음 목표!")
                        .font(.appFont(for: .SemiBold, size: 25))
                        .padding(.horizontal, 20)
                    Spacer()
                }
                HStack {
                    VStack(alignment: .leading) {
                        Text("넓이 : " + next.area.calculatedAreaString)
                            .font(.appFont(for: .Light, size: 13))
                            .foregroundStyle(Color.appTextDarkGray)
                        HStack(alignment: .bottom) {
                            Text(next.areaName)
                                .font(.appFont(for: .SemiBold, size: 30))
                            Text("까지").font(.appFont(for: .Light, size: 15))
                        }
                        Text((next.area - viewModel.myArea.area).calculatedAreaString + "남았습니다!")
                    }
                    .padding(.leading, 20)
                    Spacer()
                    Image(systemName: "pawprint.circle")
                        .font(.system(size: 68, weight: .semibold))
                        .foregroundStyle(Color.appYellow)
                        .padding(10)
                }
                .frame(maxWidth: .infinity)
                .appCardSurface()
                .padding()

            }.background(Color.appBackground)
        }

    }
}
