//
//  LimitConfigLocation.swift
//  Rotblock

import CoreLocation
import MapKit
import SwiftUI

// MARK: - Location auth helper

@Observable
final class LocationAuthMonitor: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var status: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        status = manager.authorizationStatus
        manager.delegate = self
    }

    func requestAlways() {
        manager.requestAlwaysAuthorization()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let s = manager.authorizationStatus
        Task { @MainActor in self.status = s }
    }
}

// MARK: - Location search completer

@Observable
final class LocationCompleter: NSObject, MKLocalSearchCompleterDelegate {
    var suggestions: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func update(query: String) {
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestions = []
    }
}
