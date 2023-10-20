//
//  PersistenceController.swift
//  dogArea
//
//  Created by 김태훈 on 10/20/23.
//

import Foundation
import CoreData

class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "dogArea") // 이전 단계에서 만든 모델 파일 이름과 동일해야 합니다.
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
    }

    func saveContext () {
       let context = container.viewContext
       if context.hasChanges {
           do {
               try context.save()
           } catch {

               let nserror = error as NSError
               fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
           }
       }
   }

}
