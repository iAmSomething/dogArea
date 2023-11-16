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
            let temp = areaList.map{$0.toArea()}.filter{!$0.isNil}.map{$0!}
            return temp
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
            return []
        }
    }
    func savePolygon (polygon : Polygon) -> [Polygon] {
        let polygons = PolygonEntity(context: context)
        var polygonList = [Polygon]()
        polygons.uuid = polygon.id
        polygons.walkingArea = polygon.walkingArea
        polygons.walkingTime = polygon.walkingTime
        polygons.createdAt = polygon.createdAt
        polygons.mapImage = polygon.binaryImage
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
            polygonList.append(polygon)
            print("Saved successfully!")
            return polygonList
            
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
            return polygonList
        }
    }
    func fetchPolygons() -> [Polygon] {
        var polygonList = [Polygon]()
        do {
            // Perform the fetch request
            let polygons = try context.fetch(fetchRequest)
            let temp = polygons.map{$0.toPolygon()}.filter{!$0.isNil}.map{$0!}
            polygonList = temp
            return polygonList
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
            polygonList = []
            return polygonList
        }
    }
    func deletePolygon(id: UUID) -> [Polygon] {
        // Set the predicate to filter by id
        var polygonList = [Polygon]()
        let predicate = NSPredicate(format: "uuid == %@", id as CVarArg)
        fetchRequest.predicate = predicate
        do {
            // Perform the fetch request
            let polygons = try context.fetch(fetchRequest)
            
            if let polygonToDelete = polygons.first {
                // Delete the found PolygonEntity from the context
                context.delete(polygonToDelete)
                
                // Save changes in the context
                try context.save()
                print("Deleted successfully!")
                polygonList.removeAll(where: {$0.id == id})
            } else {
                print("No PolygonEntity found with createdAt \(id)")
            }
            return polygonList
        } catch let error as NSError {
            print("Could not delete. \(error), \(error.userInfo)")
            return polygonList
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
            print("All polygons deleted successfully!")
        } catch let error as NSError {
            print("Could not delete. \(error), \(error.userInfo)")
        }
    }
#endif
}
