//
//  AuthUserInfo.swift
//  dogArea
//

import Foundation

struct AuthUserInfo: Identifiable, Hashable, TimeCheckable {
    var createdAt: TimeInterval
    let id: String
    let name: String?
}
