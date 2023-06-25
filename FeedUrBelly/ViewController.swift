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

    // UI Controls
    @IBAction func sliderValueChanged(_ sender: UISlider) {
        let currentVal = sender.value
        minimumLabel.text = "\(slider.minimumValue)"
        maximumLabel.text = "\(currentVal)"
    }

    @IBAction func buttonPressDown(_ sender: Any) {
        print("finding rest")
        if(self.currentOverLay != nil) {
            mapView.removeOverlay(self.currentOverLay)
        }
        if(self.currentAnnotation != nil) {
            mapView.removeAnnotation(self.currentAnnotation)
        }
        
        self.findRandomRestaurant()
    }
    
    func findRandomRestaurant() {
        let location = mapView.userLocation.coordinate // San Francisco coordinates, you can change this to any location
            
        let radius = 10000 // 10km radius
        
        let types = "restaurant"
        
        let urlString = "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=\(location.latitude),\(location.longitude)&radius=\(radius)&types=\(types)&key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            guard let data = data else {
                print("Error fetching data: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                print(json)
                if let results = json?["results"] as? [[String: Any]], let randomResult = results.randomElement() {
                    do {
                        let decoder = JSONDecoder()
                        let decoded = try decoder.decode(Result.self, from: data)
                        print(decoded)
                        self.places = decoded.results!
                        self.displayRandomPlaceOnMap()
                    } catch {

                        print(String(describing: error)) // <- ✅ Use this for debuging!
                    }
                    print(data)
                    let name = randomResult["name"] as? String ?? "Unknown"
                    let vicinity = randomResult["vicinity"] as? String ?? "Unknown"
                    print("Random restaurant: \(name), \(vicinity)")
                } else {
                    print("No restaurants found")
                }
            } catch {
                print("Error parsing JSON: \(error.localizedDescription)")
            }
        }
        
        task.resume()
    }
    
    func displayRandomPlaceOnMap() {
        let randomIndex = Int.random(in: 0..<places.count)
        let place = places[randomIndex]
        print()
        print(place)
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
        print("in")
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "closest food to eat in Gilbert Arizona"
        request.region = MKCoordinateRegion(
            center: location.coordinate, latitudinalMeters: 5, longitudinalMeters: 5)
        let search = MKLocalSearch(request: request)
        print(location.coordinate)
        
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.locationManager.delegate = self
        let currentVal = slider.value
        minimumLabel.text = "\(slider.minimumValue)"
        maximumLabel.text = "\(currentVal)"
        if CLLocationManager.locationServicesEnabled(){
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
       }else{
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
        if(authorizationStatus == .authorizedWhenInUse){
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

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        self.checkLocationAuthorization(authorizationStatus: status)
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(polyline: overlay as! MKPolyline)
        renderer.strokeColor = UIColor(red: 0.00, green: 0.78, blue: 0.33, alpha: 1.00)
        renderer.lineWidth = 6.0
        renderer.alpha =  1.0
        return renderer
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
