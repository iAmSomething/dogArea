//
//  StringExtensions.swift
//  dogArea
//
//  Created by 김태훈 on 11/20/23.
//

import Foundation
extension String{
    func hasLastWordBatchimKR() -> Bool {
        guard let lastText = self.last else { return false}
        let unicodeVal = UnicodeScalar(String(lastText))?.value
        guard let value = unicodeVal else { return false }
        if (value < 0xAC00 || value > 0xD7A3) { return false }
        let last = (value - 0xAC00) % 28
        return last > 0
    }
    func addYi() -> String {
        let str = self.hasLastWordBatchimKR() ? "이" : ""
        return self + str
    }
    func addUl() -> String {
        let str = self.hasLastWordBatchimKR() ? "을" : "를"
        return self + str
    }
    func addUn() -> String {
        let str = self.hasLastWordBatchimKR() ? "은" : "는"
        return self + str
    }

    /// UUID 문자열이면 소문자 canonical 형태로 반환하고, 아니면 `nil`을 반환합니다.
    var canonicalUUIDString: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false, let uuid = UUID(uuidString: trimmed) else {
            return nil
        }
        return uuid.uuidString.lowercased()
    }
}
