//
//  BaseView.swift
//  dogArea
//
//  Created by 김태훈 on 10/18/23.
//

import Foundation
import SwiftUI
final class BaseView: View {    
    @EnvironmentObject var AlertVM: CustomAlertViewModel
    var body: some View {
        // Your shared UI elements can go here, or they can be overridden in subclasses.
        EmptyView()
    }
}
