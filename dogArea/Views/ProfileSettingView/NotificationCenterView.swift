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
               Button("Capture Image") {
                   mapImageProvider.captureMapImage(for: viewModel.polygonList.last!.polygon!)
               }
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
            Text("No Image Captured")
                .foregroundColor(.gray)
        }
    }
}

#Preview {
  NotificationCenterView()
}
