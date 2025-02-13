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
private var minimumPriceVal = 0.00
private var maxmiumPriceVal = 0.00
private var keyword = ""
private var isOpenNow = false
private var filtersChanged: Bool = false

var filtersViewController: UIViewController?

class ContentViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate, UITextFieldDelegate {
    @IBOutlet weak var minimumLabel: UITextField!
    @IBOutlet weak var maximumLabel: UITextField!
    @IBOutlet weak var mySwitch: UISwitch!
    @IBOutlet weak var keywordTextField: UITextField!
    let choices = ["", "Sushi", "Steakhouse", "Diner"]

    // MARK: - UIPickerViewDataSource

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return choices.count
    }

    // MARK: - UIPickerViewDelegate

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return choices[row]
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        filtersChanged = true
        keywordTextField.text = choices[row]
        keyword = choices[row]
    }

    // MARK: - Helper method

    func createPickerView() -> UIPickerView {
        let pickerView = UIPickerView()
        pickerView.delegate = self
        return pickerView
    }
    
    @IBAction func dismissButtonPressed(_ sender: UIButton) {
        dismissFiltersPopover()
    }

    @IBAction func opneNowChanged(_ sender: UISwitch) {
        print("open now changed")
        filtersChanged = true
        if sender.isOn {
            isOpenNow = true
        } else {
            isOpenNow = false
        }
    }
    @IBAction func minimumValueChanged(_ sender: UITextField) {
        filtersChanged = true
        minimumPriceVal = Double(sender.text!) ?? 0.00
    
    }
    @IBAction func maximumValueChanged(_ sender: UITextField) {
        filtersChanged = true
        maxmiumPriceVal = Double(sender.text!) ?? 0.00
    }
    func dismissFiltersPopover() {
        filtersViewController?.dismiss(animated: true, completion: nil)
        filtersViewController = nil // Reset the property
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        print("ContentViewController loaded")
        minimumLabel.text = "\(minimumPriceVal)"
        maximumLabel.text = "\(maxmiumPriceVal)"
        mySwitch.isOn = isOpenNow
        keywordTextField.delegate = self
        keywordTextField.inputView = createPickerView()
    }
}

extension ContentViewController {
    func textFieldDidEndEditing(_ keywordTextField: UITextField) {
        keywordTextField.resignFirstResponder()
    }
    
    func textFieldShouldReturn(_ keywordTextField: UITextField) -> Bool {
        keywordTextField.resignFirstResponder()
        return true
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
}


class ViewController: UIViewController {

    // UI Dec
    @IBOutlet weak var feedButton: UIButton!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var minimumLabel: UILabel!
    @IBOutlet weak var maximumLabel: UILabel!
    @IBOutlet weak var filterButton: UIButton!

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

        minimumLabel.text = "\(Int(slider.minimumValue))mi"
        maximumLabel.text = "\(Int(currentVal))mi"
        fetchAllPlaces { [weak self] in
            // TODO: Allow them to press button after load
            DispatchQueue.main.async {
            // Enable the button once loading is complete
            self?.feedButton.isEnabled = true
            }
        }
    }

    @IBAction func filterButtonPressed(_ sender: UIButton) {
        print("filter button pressed")
        let contentViewController = storyboard?.instantiateViewController(withIdentifier: "ContentViewController") as! UIViewController

        contentViewController.modalPresentationStyle = .popover
        contentViewController.popoverPresentationController?.sourceView = sender
        contentViewController.popoverPresentationController?.sourceRect = sender.bounds
        contentViewController.popoverPresentationController?.permittedArrowDirections = .any

        present(contentViewController, animated: true, completion: nil)
        filtersViewController = contentViewController
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
        // Remove existing circle overlays
        let circleOverlays = mapView.overlays.filter { $0 is MKCircle }
        mapView.removeOverlays(circleOverlays)
        
        // Add new circle overlay
        let circle = MKCircle(center: coordinate, radius: radius)
        mapView.addOverlay(circle)

        // Create animation
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.duration = 1.0
        animation.repeatCount = .infinity
        animation.autoreverses = true
        animation.fromValue = NSNumber(value: 1.0)
        animation.toValue = NSNumber(value: 2.0)

        // Remove the problematic forEach loop that was causing the crash
        // The styling will be handled in the mapView(_:rendererFor:) delegate method
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

        if minimumPriceVal != 0.00 {
            urlString += "&minprice=\(Int(minimumPriceVal))"
        }

        if maxmiumPriceVal != 0.00 {
            urlString += "&maxprice=\(Int(maxmiumPriceVal))"
        }

        if isOpenNow {
            urlString += "&opennow=true"
        }

        if keyword != "" {
            urlString += "&keyword=\(keyword)"
        }

        print("URL STRING - " + urlString)

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
        if places.isEmpty || filtersChanged {
            print("places is empty")
            DispatchQueue.main.async {
                self.feedButton.isEnabled = false
            }
            fetchAllPlaces { [weak self] in
                // TODO: Allow them to press button after load
                DispatchQueue.main.async {
                    // Enable the button once loading is complete
                    self?.feedButton.isEnabled = true
                    filtersChanged = false
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
    func setupFilterButton() {
        let button = UIButton(type: .roundedRect)
        button.frame = CGRect(x: 50, y: 50, width: 100, height: 40)
        button.setTitle("Filters", for: .normal)

        // Set corner radius to half of the button's height for a rounded appearance
        button.layer.cornerRadius = button.frame.height / 2

        // Set background color and text color
        button.backgroundColor = UIColor.blue
        button.setTitleColor(UIColor.white, for: .normal)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // setup filter button

        // Do any additional setup after loading the view.
        self.locationManager.delegate = self
        let currentVal = slider.value
        minimumLabel.text = "\(Int(slider.minimumValue))mi"
        maximumLabel.text = "\(Int(currentVal))mi"
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
