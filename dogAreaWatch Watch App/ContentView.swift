//
//  ContentView.swift
//  dogAreaWatch Watch App
//
//  Created by 김태훈 on 12/27/23.
//

import SwiftUI
import WatchConnectivity

struct ContentView: View {
    var body: some View {
        VStack {
            Text("산책 중")
            Button(action: {},
                   label: {
                Text("영역 추가하기")
                    
            }).frame(maxWidth: .infinity,
                     maxHeight: .infinity)
            
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
