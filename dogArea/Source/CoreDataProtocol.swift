//
//  CoreDataProtocol.swift
//  dogArea
//
//  Created by 김태훈 on 11/8/23.
//

import Foundation
import CoreData
import SwiftUI
protocol CoreDataProtocol {
    var context: NSManagedObjectContext { get }
    var fetchRequest: NSFetchRequest<PolygonEntity> { get }
    var fetchAreaRequest: NSFetchRequest<AreaEntity> { get }
    func saveArea(area: AreaMeterDTO) -> Bool
    func fetchArea() -> [AreaMeterDTO]
    func savePolygon(polygon: Polygon) -> [Polygon]
    func fetchPolygons() -> [Polygon]
    func deletePolygon(id: UUID) -> [Polygon]

}
extension CoreDataProtocol {
    var context: NSManagedObjectContext {
        PersistenceController.shared.container.viewContext
    }
    var fetchRequest: NSFetchRequest<PolygonEntity> {
        let request = NSFetchRequest<PolygonEntity>(entityName: "PolygonEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return request
    }
    var fetchAreaRequest: NSFetchRequest<AreaEntity> {
        let request = NSFetchRequest<AreaEntity>(entityName: "AreaEntity")
        return request
    }

    func saveArea(area: AreaMeterDTO) -> Bool {
        let areas = AreaEntity(context: context)
        areas.areaName = area.areaName
        areas.areaSize = area.area
        areas.createdAt = area.createdAt
        do {
            try context.save()
        } catch let error as NSError {
            print("could not save. \(error), \(error.userInfo)")
            return false
        }
        return true
    }
    func fetchArea() -> [AreaMeterDTO] {
        do {
            let areaList = try context.fetch(fetchAreaRequest)
            let temp = areaList.compactMap { $0.toArea() }
            return temp
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
            return []
        }
    }
    func savePolygon (polygon : Polygon) -> [Polygon] {
        let polygons = PolygonEntity(context: context)
        polygons.uuid = polygon.id
        polygons.walkingArea = polygon.walkingArea
        polygons.walkingTime = polygon.walkingTime
        polygons.createdAt = polygon.createdAt
        polygons.mapImage = polygon.binaryImage
        polygons.petId = normalizedPetId(polygon.petId)
        for location in polygon.locations {
            let locationEntity = LocationEntity(context: context)
            locationEntity.x = (location.coordinate.latitude) as NSNumber
            locationEntity.y = (location.coordinate.longitude) as NSNumber
            locationEntity.createdAt = (location.createdAt) as NSNumber
            locationEntity.uuid = location.id
            polygons.addToLocations(locationEntity)
        }
        do {
            try context.save()
            return fetchPolygons()
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
            return fetchPolygons()
        }
    }
    func fetchPolygons() -> [Polygon] {
        backfillPolygonPetIdsFromMetadataIfNeeded()
        var polygonList = [Polygon]()
        do {
            // Perform the fetch request
            let polygons = try context.fetch(fetchRequest)
            let temp = polygons.compactMap { $0.toPolygon() }
            polygonList = temp
            return polygonList
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
            polygonList = []
            return polygonList
        }
    }
    func deletePolygon(id: UUID) -> [Polygon] {
        let request = fetchRequest
        request.predicate = NSPredicate(format: "uuid == %@", id as CVarArg)
        do {
            let polygons = try context.fetch(request)
            if let polygonToDelete = polygons.first {
                context.delete(polygonToDelete)
                try context.save()
                print("Deleted successfully!")
            } else {
                print("No PolygonEntity found with createdAt \(id)")
            }
            return fetchPolygons()
        } catch let error as NSError {
            print("Could not delete. \(error), \(error.userInfo)")
            return fetchPolygons()
        }
    }

    private func normalizedPetId(_ raw: String?) -> String? {
        guard let raw,
              raw.isEmpty == false,
              UUID(uuidString: raw) != nil else {
            return nil
        }
        return raw.lowercased()
    }

    private func backfillPolygonPetIdsFromMetadataIfNeeded() {
        let backfillFlagKey = "coredata.polygon.petid.backfill.v1.completed"
        guard UserDefaults.standard.bool(forKey: backfillFlagKey) == false else { return }

        do {
            let polygons = try context.fetch(fetchRequest)
            var didUpdate = false
            for polygon in polygons {
                if normalizedPetId(polygon.petId) != nil { continue }
                guard let sessionId = polygon.uuid,
                      let metadataPetId = normalizedPetId(WalkSessionMetadataStore.shared.petId(sessionId: sessionId)) else {
                    continue
                }
                polygon.petId = metadataPetId
                didUpdate = true
            }

            if didUpdate {
                try context.save()
            }
            UserDefaults.standard.set(true, forKey: backfillFlagKey)
        } catch let error as NSError {
            print("Could not backfill polygon petId. \(error), \(error.userInfo)")
        }
    }


#if DEBUG
    func deleteArea() {
        do {
            let areas = try context.fetch(fetchAreaRequest)
            for a in areas {
                context.delete(a)
            }
            try context.save()
        } catch let error as NSError {
            print("Could not delete. \(error), \(error.userInfo)")
        }
    }
    func deleteAllPolygons() {
        do {
            // Perform the fetch request
            let polygons = try context.fetch(fetchRequest)
            for polygon in polygons {
                // Delete each PolygonEntity from the context
                context.delete(polygon)
            }
            // Save changes in the context
            try context.save()
//            print("All polygons deleted successfully!")
        } catch let error as NSError {
            print("Could not delete. \(error), \(error.userInfo)")
        }
    }
#endif
}
