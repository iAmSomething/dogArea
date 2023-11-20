//
//  LoadingPhase.swift
//  dogArea
//
//  Created by 김태훈 on 11/20/23.
//

import Foundation
enum LoadingPhase: Equatable {
    case initial
    case loading
    case success
    case fail(msg: String)
}
