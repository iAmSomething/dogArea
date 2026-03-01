import SwiftUI

struct ThumbnailImageView: View {
    @State var image: UIImage?

    var body: some View {
        Rectangle()
            .foregroundColor(.clear)
            .frame(width: 60, height: 60)
            .background(
                Image(uiImage: image ?? .emptyImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 60)
                    .clipped()
            )
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .inset(by: 0.5)
                    .stroke(Color(red: 0.85, green: 0.85, blue: 0.85), lineWidth: 1)
            )
            .padding(.trailing, 10)
    }
}
