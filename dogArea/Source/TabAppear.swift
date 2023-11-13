//
//  TabAppear.swift
//  dogArea
//
//  Created by 김태훈 on 11/13/23.
//

import Foundation
import SwiftUI


public class TabAppear: ObservableObject {
    public static let shared = TabAppear()
    private init() {}
    
    @Published public var isTabAppear: Bool = true
    public func hide() {
            isTabAppear = false
    }
    public func appear() {
            isTabAppear = true
    }
}
