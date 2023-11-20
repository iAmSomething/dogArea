//
//  NotificationCenterView.swift
//  dogArea
//
//  Created by 김태훈 on 10/19/23.
//

import SwiftUI
import FirebaseStorage
struct NotificationCenterView: View {
    @ObservedObject var viewModel = SettingViewModel()
    @EnvironmentObject var loading: LoadingViewModel
    @State var profile: UIImage? = nil
    @State var pickerAppear: Bool = false
    @State var imgURL: String? = nil
    private var storage = Storage.storage().reference()
       var body: some View {
           VStack {
               // Display the captured image
               ImageView(image: profile)
                   .frame(width: 300, height: 300)
                   .border(Color.black)
                   .onTapGesture {
                       pickerAppear.toggle()
                   }
               .padding()
               Button(action: {
                   loading.loading()
                   guard let img = self.profile else {return}
                   viewModel.uploadImg(img: img)
                                     
               }, label: {
                   Text("업로드 하기")
               })
           }.sheet(isPresented: $pickerAppear, content: {
               ImagePicker(image: $profile, type: .photoLibrary)
           })
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
