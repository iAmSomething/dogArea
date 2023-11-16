//
//  Cluster.swift
//  dogArea
//
//  Created by 김태훈 on 11/15/23.
//

import Foundation
import CoreLocation
struct Cluster: Equatable, CustomStringConvertible {
    var description: String {
        return "센터 : \(self.center)\n 하위 클러스터 : \(sumLocs.count)개"
    }
    static func == (lhs: Cluster, rhs: Cluster) -> Bool {
        lhs.center == rhs.center
    }
    var sumLocs: [(CLLocationCoordinate2D, UUID)]
    var center: CLLocationCoordinate2D
    init(center: CLLocationCoordinate2D, id: UUID) {
        self.center = center
        self.sumLocs = [(center, id)]
    }
    mutating func updateCenter(with other: Cluster) {
        self.sumLocs.append(contentsOf: other.sumLocs)
        updateCenter()
    }
    mutating func updateCenter() {
        let sumloc = sumLocs.reduce(CLLocationCoordinate2D(latitude: 0, longitude: 0)){CLLocationCoordinate2D(latitude: $0.latitude + $1.0.latitude, longitude: $0.longitude + $1.0.longitude)}
        let count = sumLocs.count
        center = CLLocationCoordinate2D(latitude: sumloc.latitude / Double(count), longitude: sumloc.longitude / Double(count))
    }
}
final class Hiarachical: Operation {
    private var polygons: [Polygon]
    private var distance: Double
    var clusters: [Cluster]
    init(polygons: [Polygon], distance: Double) {
        self.polygons = polygons
        self.distance = distance
        self.clusters = polygons.filter{!$0.polygon.isNil}
            .map{Cluster(center: $0.polygon!.coordinate, id: $0.id)}
    }
    override var isAsynchronous: Bool {
        return true
    }
    override func main() {
        guard !isCancelled else {return}
        cluster()
    }
    private func cluster(){
        let result = calculateDistance(from: self.clusters, threshold: self.distance)
        self.clusters = result
    }
    private func calculateDistance(from clusters: [Cluster], threshold: Double) -> [Cluster] {
        var tempClusters = clusters
        var i = 0, j = 0
        while(i < tempClusters.count) {
            j = i + 1
            while(j < tempClusters.count) {
                let distance = tempClusters[i].center.distance(to: tempClusters[j].center) * 5000000
                if distance < threshold {
                    tempClusters[i].updateCenter(with: tempClusters[j])
                    tempClusters.remove(at: j)
                }
                j += 1
            }
            i += 1
        }
        return tempClusters
    }
    
}

//final class KMeans: Operation {
//    let k: Int
//    let locs: [Location]
//    var clusters: [Cluster]
//    var isChanged: Bool
//    init(k: Int, locs: [Location]) {
//        self.k = k
//        self.locs = locs
//        self.clusters = []
//        self.isChanged = false
//    }
//}
//extension KMeans {
//    override var isAsynchronous: Bool {
//        true
//    }
//    override func main() {
//        guard !isCancelled else {return}
//        run()
//    }
//    func runOperation(_ operations: [() -> Void]) {
//        guard !isCancelled else { return }
//        self.queuePriority = QueuePriority(rawValue: k + 4) ?? .high
//        operations.forEach{
//            $0()
//        }
//    }
//    func run() {
//        let maxIteration = 5
//        let initCenters = randomCentersLocations(count: k, locs: locs)
//        clusters = generateClusters(centers: initCenters)
//        runOperation([classifyPoints, updateCenters])
//        var iteration = 0
//        repeat {
//            runOperation([updatePoints, updateCenters])
//            iteration += 1
//        } while isChanged && (iteration < maxIteration) && !isCancelled
//    }
//    //MARK: - 로케이션을 k개로 나눈다음 첫 번째 값들로 초기 위치 선정
//    private func randomCentersLocations(count: Int, locs: [Location]) -> [Location] {
//        guard locs.count > count else {return locs}
//        guard let firstpoint = locs.first else {return []}
//        var result = [firstpoint]
//        switch count {
//        case 1:
//            return result
//        default :
//            let diff = locs.count / (count - 1)
//            (1..<count).forEach{
//                result.append(locs[$0 * diff - 1])
//            }
//            return result
//        }
//    }
//    //MARK: - 로케이션 배열로 클러스터 배열을 만든다.
//    private func generateClusters(centers: [Location]) -> [Cluster] {
//        let centroids = centers.map {$0.coordinate}
//        return centroids.map{Cluster(center: $0)}
//    }
//    //MARK: - 로케이션마다의 가까운 클러스터를 찾고 로케이션의 정보를 추가한다
//    private func classifyPoints() {
//        locs.forEach{
//            let cluster = findNearestCluster(loc: $0.coordinate)
//            cluster.add(loc: $0.coordinate)
//        }
//    }
//    private func updatePoints() {
//        isChanged = false
//        
//        clusters.forEach { cluster in
//            let locs = cluster.sumLocs
//            for loc in locs {
//                let nearestCluster = findNearestCluster(loc: loc)
//                if cluster == nearestCluster { continue
//                }
//                isChanged = true
//                nearestCluster.add(loc: loc)
//                cluster.remove(loc: loc)
//            }
//        }
//    }
//    //MARK: - 클러스터의 중앙값을 업데이트한다.
//    private func updateCenters() {
//        clusters.forEach {
//            $0.updateCenter()
//        }
//    }
//    //MARK: - 클러스터들마다 로케이션의 위치와의 거리를 찾고 가장 가까운 클러스터를 반환한다.
//    private func findNearestCluster(loc: CLLocationCoordinate2D) -> Cluster {
//        var minDistance = Double.greatestFiniteMagnitude
//        var nearestCluster = Cluster.greatestFinite
//        let point = loc
//        clusters.forEach {
//            let newDistance = $0.center.squaredDistance(to: point)
//            if newDistance < minDistance {
//                nearestCluster = $0
//                minDistance = newDistance
//            }
//        }
//        return nearestCluster
//    }
//}
extension CLLocationCoordinate2D {
    func squaredDistance(to : CLLocationCoordinate2D) -> Double {
        return (self.latitude - to.latitude) * (self.latitude - to.latitude) + (self.longitude - to.longitude) * (self.longitude - to.longitude)
    }
    func distance(to: CLLocationCoordinate2D) -> Double {
        return sqrt(squaredDistance(to: to))
    }
}
