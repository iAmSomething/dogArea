//
//  MapView.swift
//  dogArea
//
//  Created by 김태훈 on 10/12/23.
//

import Foundation
import UIKit
import SwiftUI

struct MapView : UIViewRepresentable {
    @ObservedObject var locationManager: LocationManager
    func makeUIView(context: Context) -> some UIView {
        locationManager.mapView
    }
    func updateUIView(_ uiView: UIViewType, context: Context) {}
}
 
