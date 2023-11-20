//
//  LoadingViewModel.swift
//  dogArea
//
//  Created by 김태훈 on 11/20/23.
//

import Foundation
import SwiftUI
class LoadingViewModel : ObservableObject {
    @Published var phase: LoadingPhase = .initial
    func failed(msg: String) {
        phase = .fail(msg: msg)
    }
    func success() {
        phase = .success
    }
    func loading() {
        phase = .loading
    }
}
