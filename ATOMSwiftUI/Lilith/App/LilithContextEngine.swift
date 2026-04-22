import Foundation
import CoreLocation
import CoreMotion
import MapKit
import Combine

// MARK: - Context Engine

final class LilithContextEngine: NSObject, ObservableObject {

    static let shared = LilithContextEngine()

    private let locationManager = CLLocationManager()
    private let motionManager   = CMMotionActivityManager()

    @Published var currentLocation: CLLocation?
    @Published var currentActivity: String = "unknown"

    private override init() {
        super.init()
    }

    // MARK: - Start

    func start() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()

        startMotionTracking()
    }

    // MARK: - Motion

    private func startMotionTracking() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }

        // Use a background queue for the CM callback; publish on main.
        let motionQueue = OperationQueue()
        motionQueue.name = "com.lilith.motion"
        motionQueue.maxConcurrentOperationCount = 1

        motionManager.startActivityUpdates(to: motionQueue) { [weak self] activity in
            guard let self, let activity else { return }
            let label: String
            if activity.walking        { label = "walking" }
            else if activity.automotive { label = "driving" }
            else if activity.stationary { label = "stationary" }
            else                        { label = "unknown" }
            DispatchQueue.main.async { self.currentActivity = label }
        }
    }

    // MARK: - Context Analysis

    func analyzeContext() {
        guard let location = currentLocation else { return }
        detectNearbyPlaces(location)
        detectMovementImpact()
    }

    // MARK: - Place Detection

    private func detectNearbyPlaces(_ location: CLLocation) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "restaurants, gym, coffee, store"
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: 1200,
            longitudinalMeters: 1200
        )

        MKLocalSearch(request: request).start { [weak self] response, _ in
            guard let self,
                  let place = response?.mapItems.first,
                  let name = place.name
            else { return }
            self.triggerContext("You're near \(name). Want to stop?")
        }
    }

    // MARK: - Movement Impact

    private func detectMovementImpact() {
        if currentActivity == "driving" {
            triggerContext("You're driving. Need directions or an ETA?")
        }

        if currentActivity == "walking" {
            triggerContext("You're walking. Want nearby suggestions?")
        }
    }

    // MARK: - Travel Time Check

    func checkTravel(to destination: MKMapItem) {
        guard let location = currentLocation else { return }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
        request.destination = destination

        MKDirections(request: request).calculate { [weak self] response, _ in
            guard let self,
                  let route = response?.routes.first
            else { return }

            if route.expectedTravelTime > 900 {
                self.triggerContext("You might be late. Want me to adjust your schedule?")
            }
        }
    }

    // MARK: - Notify UI

    private func triggerContext(_ text: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .lilithContextUpdate, object: text)
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LilithContextEngine: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
        analyzeContext()
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let lilithContextUpdate = Notification.Name("lilithContextUpdate")
}
