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

// MARK: - Global Variables
private var oneTime = false
private var currentVal = 5.0
private var minimumPriceVal = 0.00
private var maxmiumPriceVal = 0.00
private var maximumDistanceVal = 5
private var keyword = ""
private var isOpenNow = false
private var filtersChanged: Bool = false

var filtersViewController: UIViewController?

// MARK: - Filter Configuration View Controller

protocol ContentViewControllerDelegate: AnyObject {
    func didUpdateMaximumDistance(_ distance: Int)
}

class ContentViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate, UITextFieldDelegate {
    // MARK: - Outlets
    @IBOutlet weak var minimumLabel: UITextField!
    @IBOutlet weak var maximumLabel: UITextField!
    @IBOutlet weak var maximumDistance: UITextField!
    @IBOutlet weak var mySwitch: UISwitch!
    @IBOutlet weak var keywordTextField: UITextField!
    
    // MARK: - Properties
    weak var delegate: ContentViewControllerDelegate?
    let choices = ["", "Sushi", "Steakhouse", "Diner"]

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        print("ContentViewController loaded")
        minimumLabel.text = "\(minimumPriceVal)"
        maximumLabel.text = "\(maxmiumPriceVal)"
        maximumDistance.text = "\(maximumDistanceVal)"
        mySwitch.isOn = isOpenNow
        keywordTextField.delegate = self
        keywordTextField.inputView = createPickerView()
    }

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

    // MARK: - Helper Methods
    func createPickerView() -> UIPickerView {
        let pickerView = UIPickerView()
        pickerView.delegate = self
        return pickerView
    }
    
    func dismissFiltersPopover() {
        filtersViewController?.dismiss(animated: true, completion: nil)
        filtersViewController = nil // Reset the property
    }
    
    // MARK: - Actions
    @IBAction func dismissButtonPressed(_ sender: UIButton) {
        dismissFiltersPopover()
    }

    @IBAction func opneNowChanged(_ sender: UISwitch) {
        print("open now changed")
        filtersChanged = true
        isOpenNow = sender.isOn
    }
    
    @IBAction func minimumValueChanged(_ sender: UITextField) {
        filtersChanged = true
        print(sender.text!)
        minimumPriceVal = Double(sender.text!) ?? 0.00
    }
    
    @IBAction func maximumValueChanged(_ sender: UITextField) {
        filtersChanged = true
        maxmiumPriceVal = Double(sender.text!) ?? 0.00
    }
    
    @IBAction func maximumDistanceChanged(_ sender: UITextField) {
        filtersChanged = true
        if let text = sender.text, let distance = Int(text) {
            maximumDistanceVal = distance
            currentVal = Double(distance) // Sync with slider value if necessary
            print("Max distance updated to: \(distance)")
            // Notify the parent (ViewController) about the update
            delegate?.didUpdateMaximumDistance(distance)
        }
    }
}

// MARK: - TextField Extensions
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

// MARK: - Main View Controller
class ViewController: UIViewController {
    // MARK: - Outlets
    @IBOutlet weak var feedButton: UIButton!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var minimumLabel: UILabel!
    @IBOutlet weak var maximumLabel: UILabel!
    @IBOutlet weak var filterButton: UIButton!

    // MARK: - Properties
    private let locationManager = CLLocationManager()
    private let apiKey = "AIzaSyDjWDkehgCmiI35ytkHYtehRc0l6wKu-YM"
    private var places: [Place] = []
    private var currentOverLay: MKOverlay?
    private var currentAnnotation: MKAnnotation?
    private var visitedPlaces: [Place] = []
    
    // Keep these properties as references to the global variables
    // to maintain compatibility with existing code
    private var currentVal: Double {
        get { return FeedUrBelly.currentVal }
        set { FeedUrBelly.currentVal = newValue }
    }
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocationServices()
        setupUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        fetchAllPlaces { [weak self] in
            DispatchQueue.main.async {
                self?.feedButton.isEnabled = true
            }
        }
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        // Setup slider and labels
        let currentSliderVal = slider.value
        minimumLabel.text = "\(Int(slider.minimumValue))mi"
        maximumLabel.text = "\(Int(currentSliderVal))mi"
        
        // Center feed button
        feedButton.center.x = self.view.center.x
        feedButton.isEnabled = false
    }
    
    private func setupLocationServices() {
        locationManager.delegate = self
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
        } else {
            print("Error: GPS not available")
        }
        
        locationManager.requestAlwaysAuthorization()
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        let authorizationStatus: CLAuthorizationStatus
        if #available(iOS 14, *) {
            authorizationStatus = locationManager.authorizationStatus
        } else {
            authorizationStatus = CLLocationManager.authorizationStatus()
        }
        
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways || authorizationStatus == .authorized {
            mapView.delegate = self
            mapView.overrideUserInterfaceStyle = .dark
            mapView.frame = self.view.bounds
            mapView.showsUserLocation = true
            checkLocationAuthorization()
        }
    }
    
    // MARK: - UI Actions
    @IBAction func sliderValueChanged(_ sender: UISlider) {
        currentVal = Double(sender.value)
        animateCircle(coordinate: mapView.userLocation.coordinate, radius: 1609.34 * currentVal)
        
        minimumLabel.text = "\(Int(slider.minimumValue))mi"
        maximumLabel.text = "\(Int(currentVal))mi"
        
        fetchAllPlaces { [weak self] in
            DispatchQueue.main.async {
                self?.feedButton.isEnabled = true
            }
        }
    }

    @IBAction func filterButtonPressed(_ sender: UIButton) {
        print("Filter button pressed")
        guard let contentViewController = storyboard?.instantiateViewController(withIdentifier: "ContentViewController") as? ContentViewController else {
            print("Failed to instantiate ContentViewController")
            return
        }
        
        // Set the delegate
        contentViewController.delegate = self
        
        contentViewController.modalPresentationStyle = .popover
        contentViewController.popoverPresentationController?.sourceView = sender
        contentViewController.popoverPresentationController?.sourceRect = sender.bounds
        contentViewController.popoverPresentationController?.permittedArrowDirections = .any
        
        present(contentViewController, animated: true, completion: nil)
        filtersViewController = contentViewController
    }
    
    @IBAction func buttonPressDown(_ sender: Any) {
        print("Finding restaurant")
        clearMapOverlays()
        displayRandomPlaceOnMap()
    }
    
    // MARK: - Map Methods
    private func clearMapOverlays() {
        if let overlay = currentOverLay {
            mapView.removeOverlay(overlay)
        }
        
        if currentAnnotation != nil {
            mapView.removeAnnotations(mapView.annotations)
        }
    }
    
    func animateCircle(coordinate: CLLocationCoordinate2D, radius: CLLocationDistance) {
        // Remove existing circle overlays
        let circleOverlays = mapView.overlays.filter { $0 is MKCircle }
        mapView.removeOverlays(circleOverlays)
        
        // Add new circle overlay
        let circle = MKCircle(center: coordinate, radius: radius)
        mapView.addOverlay(circle)
    }
    
    // MARK: - Restaurant Data Methods
    func fetchAllPlaces(completion: @escaping () -> Void) {
        places = [] // Clear previous places before fetching new ones
        fetchPlaces(withPageToken: nil, completion: completion)
    }
    
    func fetchPlaces(withPageToken pageToken: String?, completion: @escaping () -> Void) {
        print("Fetching places")
        
        guard let userLocation = locationManager.location?.coordinate else {
            print("User location not available")
            completion()
            return
        }
        
        let radius = 1609.34 * currentVal // Convert miles to meters
        let types = "restaurant"
        
        var urlString = "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=\(userLocation.latitude),\(userLocation.longitude)&radius=\(radius)&types=\(types)&key=\(apiKey)"
        
        if let token = pageToken {
            urlString += "&pagetoken=\(token)"
        }
        
        // Add filters
        if minimumPriceVal != 0.00 {
            urlString += "&minprice=\(Int(minimumPriceVal))"
        }
        
        if maxmiumPriceVal != 0.00 {
            urlString += "&maxprice=\(Int(maxmiumPriceVal))"
        }
        
        if isOpenNow {
            urlString += "&opennow=true"
        }
        
        if !keyword.isEmpty {
            urlString += "&keyword=\(keyword)"
        }
        
        print("Request URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            completion()
            return
        }
        
        // Perform the API request
        let task = URLSession.shared.dataTask(with: url) { [weak self] (data, response, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Error: \(error.localizedDescription)")
                completion()
                return
            }
            
            guard let data = data else {
                print("No data received")
                completion()
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let decodedResponse = try decoder.decode(Result.self, from: data)
                
                if let newPlaces = decodedResponse.results {
                    print("Adding \(newPlaces.count) results")
                    self.places.append(contentsOf: newPlaces)
                }
                
                // Check for next page token
                let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                if let nextPageToken = json?["next_page_token"] as? String {
                    // Delay before fetching next page (required by Google API)
                    print("Getting next page with token: \(nextPageToken)")
                    print("Current place count: \(self.places.count)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.fetchPlaces(withPageToken: nextPageToken, completion: completion)
                    }
                } else {
                    completion() // All results fetched
                }
            } catch {
                print("Error parsing data: \(error.localizedDescription)")
                completion()
            }
        }
        
        task.resume()
    }
    
    func displayRandomPlaceOnMap() {
        // Check if places are available
        if places.isEmpty || filtersChanged {
            print("Places are empty or filters changed. Fetching new places...")
            DispatchQueue.main.async {
                self.feedButton.isEnabled = false
            }
            
            fetchAllPlaces { [weak self] in
                DispatchQueue.main.async {
                    self?.feedButton.isEnabled = true
                    filtersChanged = false
                    self?.displayRandomPlaceOnMap()
                }
            }
            return
        }
        
        // Select a random place that hasn't been visited
        let randomIndex = Int.random(in: 0..<places.count)
        let place = places[randomIndex]
        
        // Skip already visited places
        if visitedPlaces.contains(where: { $0.name == place.name }) {
            // Try again if we've visited this place already
            if visitedPlaces.count < places.count {
                displayRandomPlaceOnMap()
            } else {
                print("All places have been visited!")
            }
            return
        }
        
        visitedPlaces.append(place)
        print("Selected place: \(place.name ?? "Unnamed")")
        
        // Create and add an annotation for the place
        guard let locationCoordinate = place.geometry?.location?.coordinate else {
            print("Invalid place coordinates")
            return
        }
        
        let annotation = MKPointAnnotation()
        annotation.coordinate = locationCoordinate
        annotation.title = place.name
        
        mapView.addAnnotation(annotation)
        currentAnnotation = annotation
        
        // Set the map region to focus on the selected place
        let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        let region = MKCoordinateRegion(center: locationCoordinate, span: span)
        
        DispatchQueue.main.async {
            self.mapView.setRegion(region, animated: true)
        }
        
        // Create a route from current location to the selected place
        createRoute(to: locationCoordinate)
    }
    
    private func createRoute(to destination: CLLocationCoordinate2D) {
        guard let userLocation = locationManager.location?.coordinate else {
            print("User location not available")
            return
        }
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .any
        request.requestsAlternateRoutes = false
        
        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            guard let self = self, let directionsResponse = response else {
                if let error = error {
                    print("Error calculating directions: \(error.localizedDescription)")
                }
                return
            }
            
            if let route = directionsResponse.routes.first {
                DispatchQueue.main.async {
                    self.mapView.addOverlay(route.polyline)
                    self.currentOverLay = route.polyline
                }
            }
        }
    }
    
    // MARK: - Location Authorization
    func checkLocationAuthorization(authorizationStatus: CLAuthorizationStatus? = nil) {
        let status = authorizationStatus ?? CLLocationManager.authorizationStatus()
        
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            mapView.showsUserLocation = true
            
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            
        default:
            print("Location Services: Denied / Restricted")
        }
    }
}

// MARK: - Map & Location Delegate Extensions
extension ViewController: MKMapViewDelegate, CLLocationManagerDelegate {
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        if !oneTime {
            let span = MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
            let region = MKCoordinateRegion(center: userLocation.coordinate, span: span)
            mapView.setRegion(region, animated: true)
            oneTime = true
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            animateCircle(coordinate: location.coordinate, radius: 1609.34 * currentVal)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        checkLocationAuthorization(authorizationStatus: status)
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
            renderer.alpha = 1.0
            return renderer
        }
        
        return MKOverlayRenderer()
    }
}

// MARK: - Delegate Implementation
extension ViewController: ContentViewControllerDelegate {
    func didUpdateMaximumDistance(_ distance: Int) {
        print("Distance updated to: \(distance)")
        DispatchQueue.main.async {
            // Update the global variable
            FeedUrBelly.currentVal = Double(distance)
            self.animateCircle(coordinate: self.mapView.userLocation.coordinate, radius: 1609.34 * Double(distance))
            self.maximumLabel.text = "\(distance)mi"
            
            // Fetch new places with updated distance
            self.fetchAllPlaces { [weak self] in
                DispatchQueue.main.async {
                    self?.feedButton.isEnabled = true
                }
            }
        }
    }
}

// MARK: - Data Models
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
