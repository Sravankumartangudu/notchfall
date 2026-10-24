import CoreLocation
import MapKit

/// 🚗 How long it takes to get from here to a meeting's address, from Apple Maps. Only meetings with a
/// physical address are looked up, each at most every 10 minutes, and nothing is asked for (not even
/// location access) until there's such a meeting coming up.
final class Travel: NSObject, CLLocationManagerDelegate {
    var onChange: () -> Void = {}

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var here: CLLocation?
    private var places: [String: CLPlacemark] = [:]
    private var etas: [String: (minutes: Int, at: Date)] = [:]
    private var tried: [String: Date] = [:]        // when each lookup was last started, ok or not
    private var busy = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var denied: Bool { [.denied, .restricted].contains(manager.authorizationStatus) }

    /// Travel minutes to `place`, if Maps has answered.
    func minutes(to place: String, by transport: String) -> Int? { etas[key(place, transport)]?.minutes }

    /// Looks up (one at a time) whichever of these places has no fresh travel time.
    func update(_ wanted: [String], by transport: String) {
        guard !wanted.isEmpty else { return }
        switch manager.authorizationStatus {
        case .notDetermined: return manager.requestWhenInUseAuthorization()
        case .denied, .restricted: return
        default: break
        }
        if here.map({ Date().timeIntervalSince($0.timestamp) > 600 }) ?? true { manager.requestLocation() }
        guard let here, !busy else { return }
        let now = Date()
        guard let place = wanted.first(where: { p in
            let k = key(p, transport)
            return (etas[k].map { now.timeIntervalSince($0.at) > 600 } ?? true)
                && (tried[k].map { now.timeIntervalSince($0) > 300 } ?? true)
        }) else { return }
        let k = key(place, transport)
        tried[k] = now
        busy = true
        placemark(place) { [weak self] pm in
            guard let self else { return }
            guard let pm else { self.busy = false; return }
            let req = MKDirections.Request()
            req.source = MKMapItem(placemark: MKPlacemark(coordinate: here.coordinate))
            req.destination = MKMapItem(placemark: MKPlacemark(placemark: pm))
            req.transportType = transport == "walking" ? .walking : transport == "transit" ? .transit : .automobile
            MKDirections(request: req).calculateETA { [weak self] resp, _ in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.busy = false
                    if let t = resp?.expectedTravelTime {
                        self.etas[k] = (max(1, Int((t / 60).rounded(.up))), Date())
                        self.onChange()
                    }
                }
            }
        }
    }

    private func placemark(_ place: String, _ done: @escaping (CLPlacemark?) -> Void) {
        if let pm = places[place] { return done(pm) }
        geocoder.geocodeAddressString(place) { [weak self] list, _ in
            DispatchQueue.main.async {
                let pm = list?.first
                if let pm { self?.places[place] = pm }
                done(pm)
            }
        }
    }

    private func key(_ place: String, _ transport: String) -> String { "\(transport)|\(place)" }

    /// Apple Maps directions from here to the address.
    static func directions(to place: String, by transport: String) -> URL? {
        var c = URLComponents(string: "https://maps.apple.com/")!
        let flag = transport == "walking" ? "w" : transport == "transit" ? "r" : "d"
        c.queryItems = [URLQueryItem(name: "daddr", value: place), URLQueryItem(name: "dirflg", value: flag)]
        return c.url
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let l = locations.last else { return }
        let moved = here.map { $0.distance(from: l) > 500 } ?? true
        here = l
        if moved { etas.removeAll(); tried.removeAll() }
        onChange()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { onChange() }
}
