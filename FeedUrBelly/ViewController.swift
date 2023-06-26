//
//  ViewController.swift
//  FeedUrBelly
//
//  Created by Austin Efnor on 3/16/23.
//

import UIKit
import MapKit
import CoreLocation
import Foundation

// Global Vars
private var oneTime = false
private var currentVal = 5.0

class ViewController: UIViewController {

    // UI Dec
    @IBOutlet weak var feedButton: UIButton!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var minimumLabel: UILabel!
    @IBOutlet weak var maximumLabel: UILabel!

    var locationManager = CLLocationManager()
    let apiKey = "AIzaSyDjWDkehgCmiI35ytkHYtehRc0l6wKu-YM"
    var places: [Place] = []
    var currentOverLay: MKOverlay!
    var currentAnnotation: MKAnnotation!
    var visitedPlaces: [Place] = []

    // UI Controls
    @IBAction func sliderValueChanged(_ sender: UISlider) {
        currentVal = Double(sender.value)
        animateCircle(coordinate: mapView.userLocation.coordinate, radius: 1609.34 * Double(currentVal)) // For example, 1 kilometer radius

        minimumLabel.text = "\(Int(slider.minimumValue))"
        maximumLabel.text = "\(Int(currentVal))"
        fetchAllPlaces { [weak self] in
            // TODO: Allow them to press button after load
            DispatchQueue.main.async {
            // Enable the button once loading is complete
            self?.feedButton.isEnabled = true
            }
        }
    }

    @IBAction func buttonPressDown(_ sender: Any) {
        print("finding rest")
        if(self.currentOverLay != nil) {
            print(mapView.overlays)
            mapView.removeOverlay(self.currentOverLay)
        }
        if(self.currentAnnotation != nil) {
            mapView.removeAnnotations(mapView.annotations)
        }
        
        self.displayRandomPlaceOnMap()
    }
    
    func animateCircle(coordinate: CLLocationCoordinate2D, radius: CLLocationDistance) {
        let circleOverlays = mapView.overlays.filter { $0 is MKCircle }
        mapView.removeOverlays(circleOverlays)
        let circle = MKCircle(center: coordinate, radius: radius)
        mapView.addOverlay(circle)

        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.duration = 1.0
        animation.repeatCount = .infinity
        animation.autoreverses = true
        animation.fromValue = NSNumber(value: 1.0)
        animation.toValue = NSNumber(value: 2.0)

        mapView.overlays.forEach { overlay in
            if overlay is MKCircle {
                let circleRenderer = mapView.renderer(for: overlay) as! MKCircleRenderer
                circleRenderer.alpha = 0.8
                circleRenderer.lineWidth = 2.0
                circleRenderer.strokeColor = UIColor.blue
                circleRenderer.fillColor = UIColor.blue.withAlphaComponent(0.2)
                // circleRenderer.layer.add(animation, forKey: "opacityAnimation")
                // circleRenderer.overlay.shape.add(animation, forKey: "pulse")
                // mapView.layer.add(animation, forKey: "pulse")
            }
        }
    }

    func fetchPlaces(withPageToken pageToken: String?, completion: @escaping () -> Void) {
        print("Fetching places")
        // Set up the URL request
        let location = mapView.userLocation.coordinate // San Francisco coordinates, you can change this to any location
            
        let radius = 1609.34 * Double(currentVal) // 1mi in meters * currentVal aka more miles
        
        let types = "restaurant"
        
        var urlString = "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=\(location.latitude),\(location.longitude)&radius=\(radius)&types=\(types)&key=\(apiKey)"
        // var urlString = "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=37.7749,-122.4194&radius=1000&type=restaurant&key=YOUR_API_KEY"

        if let token = pageToken {
            urlString += "&pagetoken=\(token)"
        }

        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }

        // Perform the API request
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                print("No data received")
                return
            }
            print("Data received", data)
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                // print(urlString)
                // print("JSON received", json)

                // Parse the response JSON
                if let results = json?["results"] as? [[String: Any]] {
                    do {
                        let decoder = JSONDecoder()
                        let decoded = try decoder.decode(Result.self, from: data)
                        print("Adding Results!")
                        self.places = self.places + decoded.results!
                    } catch {

                        print(String(describing: error)) // <- ✅ Use this for debuging!
                    }
                }

                // Check if there is a next page token
                if let nextPageToken = json?["next_page_token"] as? String {
                    // Delay a bit before fetching the next page to allow for processing
                    print("Getting next page", nextPageToken)
                    print(self.places.count)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.fetchPlaces(withPageToken: nextPageToken, completion: completion)
                    }
                } else {
                    completion() // Call the completion handler when all results have been fetched
                }

            } catch {
                print("JSON parsing error: \(error.localizedDescription)")
            }
        }

        task.resume()
    }
    
    func displayRandomPlaceOnMap() {
        // if places is empty, return
        if places.isEmpty {
            print("places is empty")
            DispatchQueue.main.async {
                self.feedButton.isEnabled = false
            }
            fetchAllPlaces { [weak self] in
                // TODO: Allow them to press button after load
                DispatchQueue.main.async {
                // Enable the button once loading is complete
                self?.feedButton.isEnabled = true
                self?.displayRandomPlaceOnMap()
                }
            }
            return
        }
        let randomIndex = Int.random(in: 0..<places.count)
        let place:Place = places[randomIndex]
        if visitedPlaces.contains(where: { $0.name == place.name }) {
            displayRandomPlaceOnMap()
            return
        }
        visitedPlaces.append(place)
        print(visitedPlaces)
        let annotation = MKPointAnnotation()
        annotation.coordinate = (place.geometry?.location!.coordinate)!
        annotation.title = place.name
        
        mapView.addAnnotation(annotation)
        
        currentAnnotation = annotation
        
            
        let location = (place.geometry?.location!.coordinate)!
        let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude), span: span) // adjust the region to your desired zoom level
        DispatchQueue.main.async {
            self.mapView.setRegion(region, animated: true)
        }
        
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: locationManager.location?.coordinate.latitude ?? 0.0, longitude: locationManager.location?.coordinate.longitude ?? 0.0)))
        let locRequest = CLLocationCoordinate2D(latitude: (place.geometry?.location!.coordinate.latitude)!, longitude: (place.geometry?.location!.coordinate.longitude)!)
        
        request.destination  = MKMapItem(placemark: (MKPlacemark(coordinate: locRequest)))
        request.transportType = .any
        request.requestsAlternateRoutes = false
        
        let directions = MKDirections(request: request)
        directions.calculate{response, error in
            guard let directionsResponse = response else {return}
            for route in directionsResponse.routes  {
                DispatchQueue.main.async {
                    self.mapView.addOverlay(route.polyline)
                    self.currentOverLay = route.polyline
                }
            }
        }
    }
    
    func findRestaurantsNear(location: MKUserLocation, region: MKCoordinateRegion){
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "closest food to eat in Gilbert Arizona"
        request.region = MKCoordinateRegion(
            center: location.coordinate, latitudinalMeters: 5, longitudinalMeters: 5)
        let search = MKLocalSearch(request: request)
        
        search.start(completionHandler: {(response, error) in
               
               if error != nil {
                  print("Error occured in search: \(error!.localizedDescription)")
               } else if response!.mapItems.count == 0 {
                  print("No matches found")
               } else {
                  print("Matches found")
                  
                  guard let validResponse = response else {return}

                  //Instead of looping through all of the items, pick one.
                  let item = validResponse.mapItems.randomElement()
                
                   print("item = \(String(describing: item))")
                   print("Name = \(String(describing: item?.name))")
                   print("Phone = \(String(describing: item?.phoneNumber))")
               }
            })
        
    }
    
    func fetchAllPlaces(completion: @escaping () -> Void) {
        fetchPlaces(withPageToken: nil, completion: completion)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.locationManager.delegate = self
        let currentVal = slider.value
        minimumLabel.text = "\(Int(slider.minimumValue))"
        maximumLabel.text = "\(Int(currentVal))"
        if CLLocationManager.locationServicesEnabled(){
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
       } else {
            print ("Err GPS")
       }
        locationManager.requestAlwaysAuthorization()
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()

        let authorizationStatus: CLAuthorizationStatus
        if #available(iOS 14, *) {
            authorizationStatus = locationManager   .authorizationStatus
        } else {
            authorizationStatus = CLLocationManager.authorizationStatus()
        }
        DispatchQueue.main.async {
            self.feedButton.isEnabled = false
        }
        // when we have any type of authorization, we can start using the map
        if(authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways || authorizationStatus == .authorized){
            mapView.delegate = self;
            mapView.overrideUserInterfaceStyle = .dark
            mapView.frame = self.view.bounds
            locationManager.delegate = self
            mapView.showsUserLocation = true
            self.checkLocationAuthorization()
            feedButton.center.x = self.view.center.x
        }
        
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        fetchAllPlaces { [weak self] in
            // TODO: Allow them to press button after load
            DispatchQueue.main.async {
            // Enable the button once loading is complete
                self?.feedButton.isEnabled = true
            }
        }
    }
    
    func checkLocationAuthorization(authorizationStatus: CLAuthorizationStatus? = nil) {
            switch (authorizationStatus ?? CLLocationManager.authorizationStatus()) {
            case .authorizedAlways, .authorizedWhenInUse:
                mapView.showsUserLocation = true
            case .notDetermined:
                if locationManager == nil {
                    locationManager = CLLocationManager()
                    locationManager.delegate = self
                }
                locationManager.requestWhenInUseAuthorization()
            default:
                print("Location Servies: Denied / Restricted")
            }
        }
}
// Extension Functions
extension ViewController: MKMapViewDelegate, CLLocationManagerDelegate {
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        if(!oneTime){
            let span = MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
            let region = MKCoordinateRegion(center: userLocation.coordinate, span: span)
            mapView.frame = self.view.bounds
            mapView.setRegion(region, animated: true)
            oneTime = true
        }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            // Call animateCircle with desired radius (in meters) and take the radius in miles and multiple that by the sliders value
            animateCircle(coordinate: location.coordinate, radius: 1609.34 * Double(currentVal)) // For example, 1 kilometer radius
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        self.checkLocationAuthorization(authorizationStatus: status)
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKCircle {
            let renderer = MKCircleRenderer(overlay: overlay)
            renderer.fillColor = UIColor.blue.withAlphaComponent(0.2)
            renderer.strokeColor = UIColor.blue.withAlphaComponent(0.7)
            renderer.lineWidth = 2.0
            return renderer
        }
        if overlay is MKPolyline {
            let renderer = MKPolylineRenderer(polyline: overlay as! MKPolyline)
            renderer.strokeColor = UIColor(red: 0.00, green: 0.78, blue: 0.33, alpha: 1.00)
            renderer.lineWidth = 6.0
            renderer.alpha =  1.0
            return renderer
        }
        return MKOverlayRenderer()
    }
}

// Models for JSON decoding
struct Result: Codable {
    let results: [Place]?
}

struct Place: Codable {
    let name: String?
    let geometry: Geometry?
    let vicinity: String?
}

struct Geometry: Codable {
    let location: Location?
}

struct Location: Codable {
    let lat: Double?
    let lng: Double?
    
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: lat ?? 0, longitude: lng ?? 0)
    }
}
