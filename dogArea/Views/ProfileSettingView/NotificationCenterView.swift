//
//  NotificationCenterView.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import SwiftUI

struct NotificationCenterView: View {
    @ObservedObject var mapImageProvider = MapImageProvider()
    @ObservedObject var viewModel = SettingViewModel()

       var body: some View {
           VStack {
               // Display the captured image
               ImageView(image: mapImageProvider.capturedImage)
                   .frame(width: 300, height: 300)
                   .border(Color.black)

               // Button to trigger image capture
               .padding()
           }
       }
}
struct ImageView: View {
    let image: UIImage?

    var body: some View {
        if let image = image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Text("프로필 이미지")
                .foregroundColor(.gray)
        }
    }
}

#Preview {
  NotificationCenterView()
}
