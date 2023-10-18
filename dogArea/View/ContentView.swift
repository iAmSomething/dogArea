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
    var AlertVM: CustomAlertViewModel = .init()
    @State var presentAlert = false

    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    var body: some View {
        NavigationSplitView {
            ZStack{
                VStack {
                    MapView(locationManager: AlertVM.loc)
                        .frame(maxWidth: .infinity)
                        .ignoresSafeArea()
                    Text("\(self.AlertVM.loc.location.0) , \(self.AlertVM.loc.location.1)")
                    HStack {
                        Button(action: {
                            AlertVM.toggleTest()
                        },label: {Text("위치 정보 찾아보기")})
                        Button(action: {
                            print(items)
                            AlertVM.loc.clear()
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
                    AlertVM.callAlert(type: .addPoint,state: $presentAlert)
                }
            }.modifier(AlertViewModifier())
        } detail: {
            Text("Select an item")
        }
    }
    
    private func addItem() {
        withAnimation {
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
