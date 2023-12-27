//
//  ContentsViewModel.swift
//  dogAreaWatch Watch App
//
//  Created by 김태훈 on 12/27/23.
//

import Foundation
import WatchConnectivity

class ContentsViewModel: ObservableObject {
    @Published var receiveData = WCSession.default.receivedApplicationContext
    func fetchData() {
        if receiveData.isEmpty == false {
            DispatchQueue.main.async {
                if let  data = self.receiveData.values.first as? TimeInterval {
                    
                }
            }
        }
    }
}
