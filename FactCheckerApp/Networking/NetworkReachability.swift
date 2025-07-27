//
//  NetworkReachability.swift
//  FactCheckerApp
//
//  Created by Nicholas Myer on 7/25/25.
//


import Network
import Foundation

class NetworkReachability: ObservableObject {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkReachability")
    
    @Published var status: NetworkStatus = .unknown
    
    enum NetworkStatus {
        case unknown
        case notReachable
        case reachableViaWiFi
        case reachableViaCellular
        case reachableViaEthernet
    }
    
    func startMonitoring(statusUpdateHandler: @escaping (NetworkStatus) -> Void) {
        monitor.pathUpdateHandler = { [weak self] path in
            let status = self?.getNetworkStatus(from: path) ?? .unknown
            
            DispatchQueue.main.async {
                self?.status = status
                statusUpdateHandler(status)
            }
        }
        
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
    
    private func getNetworkStatus(from path: NWPath) -> NetworkStatus {
        if path.status == .satisfied {
            if path.usesInterfaceType(.wifi) {
                return .reachableViaWiFi
            } else if path.usesInterfaceType(.cellular) {
                return .reachableViaCellular
            } else if path.usesInterfaceType(.wiredEthernet) {
                return .reachableViaEthernet
            }
        }
        return .notReachable
    }
}
