//
//  ContentView.swift
//  dogArea
//
//  Created by 김태훈 on 10/12/23.
//

import SwiftUI
import SwiftData
import CoreLocation
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @ObservedObject var loc: LocationManager = .init()
    @State var isp = true
    @State var presentAlert = false
    
    var body: some View {
        NavigationSplitView {
            ZStack{
                VStack {
                    MapView(locationManager: loc)
                        .frame(maxWidth: .infinity)
                    Text("\(self.loc.location.0) , \(self.loc.location.1)")
                    HStack {
                        Button(action: {
                            loc.callLocation()
                        },label: {Text("위치 정보 찾아보기")})
                        .alert("", isPresented: $isp, actions: {})
                        Button(action: {
                            print(items)
                            loc.clear()
                        }, label: {
                            Text("초기화")
                        })

                    }
                    
                }
                Image("addPointBtn", bundle: nil)
                    .resizable()
                    .frame(width: 55, height: 55)
                    .aspectRatio(contentMode: .fit)
                    .position(CGPoint(x: (UIScreen.main.bounds.width) * 90/100,
                                      y: (UIScreen.main.bounds.height) * 75/100))
                    .onTapGesture {
                        presentAlert.toggle()
                    }
                if presentAlert {
                    CustomAlert(presentAlert: $presentAlert,
                                alertType: .customValue(title: "오줌 누기", message: "오줌 눴나요?", configure: .oneButton(buttonMsg: "네 맞아요"))
                                )
                    {
                        loc.callLocation()
                    } rightButtonAction: {
                        withAnimation{
                        }
                    }
                }
            }
        } detail: {
            Text("Select an item")
        }
    }
    
    private func addItem() {
        withAnimation {
            guard let polygon = loc.area else {return}
            let newItem = Item(timestamp: Date() )
            modelContext.insert(newItem)
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
