import SwiftUI

struct SimpleKeyValueView: View {
    var value: (String, String)

    var body: some View {
        VStack {
            Text(value.0)
                .font(.appFont(for: .Regular, size: 20))
                .multilineTextAlignment(.center)
                .foregroundColor(.black)
                .padding(.horizontal, 30)
            Text(value.1)
                .font(.appFont(for: .Regular, size: 20))
                .multilineTextAlignment(.center)
                .foregroundColor(.black)
        }
        .foregroundColor(.clear)
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background(.white)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .inset(by: 0.5)
                .stroke(Color.appTextLightGray, lineWidth: 0.5)
        )
        .aspectRatio(contentMode: .fit)
    }
}
