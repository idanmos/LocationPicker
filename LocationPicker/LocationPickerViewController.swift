//
//  LocationPickerViewController.swift
//  LocationPicker
//
//  Created by Idan Moshe on 30/01/2021.
//

import UIKit
import CoreLocation
import MapKit

private let radius: Double = 1000.0

class LocationMapItem {
    
    private let item: MKMapItem
    init(_ mapItem: MKMapItem) {
        self.item = mapItem
    }
    
    let uuid = UUID()
    
    var name: String {
        return self.item.name ?? ""
    }
    
    var coordinate: CLLocationCoordinate2D {
        return self.item.placemark.coordinate
    }
    
    var title: String {
        return "\(self.item.placemark.thoroughfare ?? "") \(self.item.placemark.subThoroughfare ?? ""), \(self.item.placemark.locality ?? "")"
    }
    
}

class LocationPickerTableViewCell: UITableViewCell {
    
    deinit {
        debugPrint("Deallocating \(self)")
        self.imageView?.image = nil
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.imageView?.image = UIImage(systemName: "location")
        self.imageView?.layer.masksToBounds = true
        self.imageView?.clipsToBounds = true
        self.imageView?.backgroundColor = .systemGroupedBackground
        self.imageView?.layer.cornerRadius = (self.imageView?.frame.size.height)!/2.0
        self.imageView?.isHidden = false
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}

// MARK: - Protocol LocationPickerViewControllerDelegate

protocol LocationPickerViewControllerDelegate: class {
    func locationPicker(_ locationPicker: LocationPickerViewController, didSelect mapItem: LocationMapItem)
}

// MARK: - LocationPickerViewController

class LocationPickerViewController: UIViewController {
    
    @IBOutlet private weak var mapView: MKMapView!
    @IBOutlet private weak var tableView: UITableView!
    
    weak var delegate: LocationPickerViewControllerDelegate?
    
    private lazy var dataSource: [LocationMapItem] = []
    private var locationManager: CLLocationManager!
    private var didZoomToUserLocation: Bool = false
    private var localSearch: MKLocalSearch!
    private var selectedMapItem: LocationMapItem?
    
    private lazy var cancelButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(self.onPressCloseButtonItem(_:)))
    }()
    
    private lazy var refreshlButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(self.onPressRefreshButtonItem(_:)))
    }()
    
    private lazy var searchResultsController: LocationPickerSearchResultsTableViewController = {
        let controller = LocationPickerSearchResultsTableViewController(style: .plain)
        controller.searchDelegate = self
        return controller
    }()
    
    private lazy var searchController: UISearchController = {
        let controller = UISearchController(searchResultsController: self.searchResultsController)
        controller.searchResultsUpdater = self
        controller.searchBar.delegate = self
        controller.hidesNavigationBarDuringPresentation = false
        return controller
    }()
    
    private lazy var calloutAccessoryView: UIButton = {
        let button = UIButton(type: .custom)
        button.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
        button.setBackgroundImage(UIImage(systemName: "checkmark.circle"), for: .normal)
        button.tintColor = .systemGreen
        return button
    }()
    
    deinit {
        debugPrint("Deallocating \(self)")
        self.dataSource.removeAll()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = NSLocalizedString("choose_location", comment: "")
        self.navigationItem.searchController = self.searchController
        
        self.navigationItem.leftBarButtonItem = self.cancelButtonItem
        self.navigationItem.rightBarButtonItem = self.refreshlButtonItem
        
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.register(LocationPickerTableViewCell.self, forCellReuseIdentifier: "LocationPickerTableViewCell")
        self.tableView.tableFooterView = UIView(frame: .zero)
        
        self.mapView.delegate = self
        self.mapView.showsScale = true
        self.mapView.showsTraffic = true
        self.mapView.showsBuildings = true
        self.mapView.showsLargeContentViewer = true
        self.mapView.showsUserLocation = true
        
        self.locationManager = CLLocationManager()
        self.locationManager.delegate = self
        self.locationManager.activityType = .automotiveNavigation
        self.locationManager.distanceFilter = 10
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

}
// MARK: - General Methods


extension LocationPickerViewController {
    private func selectMapItem(_ mapItem: LocationMapItem, addToList: Bool = false) {
        self.selectedMapItem = mapItem
        
        let region = MKCoordinateRegion(
            center: mapItem.coordinate,
            latitudinalMeters: radius,
            longitudinalMeters: radius
        )
        
        self.mapView.setRegion(region, animated: true)
        
        let removedAnnotations: [MKAnnotation] = self.mapView.annotations.filter({ $0 is MKPointAnnotation })
        self.mapView.removeAnnotations(removedAnnotations)
                
        let annotation = MKPointAnnotation()
        annotation.coordinate = mapItem.coordinate
        
        if mapItem.name.count > 0 {
            annotation.title = mapItem.name
            annotation.subtitle = mapItem.title
        } else {
            annotation.title = mapItem.title
        }
        
        self.mapView.addAnnotation(annotation)
        self.mapView.selectAnnotation(annotation, animated: true)
        
        if addToList {
            self.dataSource.insert(mapItem, at: 0)
        } else {
            let index = self.dataSource.firstIndex(where: { $0.uuid == mapItem.uuid })
            if let index = index {
                self.dataSource.move(from: index, to: 0)
            }
        }
        
        self.tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
    }
}

// MARK: - Action Handlers

extension LocationPickerViewController {
    
    @objc private func onPressCloseButtonItem(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc private func onPressRefreshButtonItem(_ sender: Any) {
        if self.searchController.isActive {
            self.searchController.searchBar.text = nil
            self.searchResultsController.dismiss(animated: true, completion: nil)
        }
        self.locationManager.stopUpdatingLocation()
        self.dataSource.removeAll()
        self.tableView.reloadData()
        self.locationManager.startUpdatingLocation()
    }
    
}

// MARK: - UISearchResultsUpdating

extension LocationPickerViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        guard let searchText = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines), searchText.count >= 2 else { return }
        
        if searchText.isEmpty {
            self.searchResultsController.dataSource.removeAll()
            self.searchResultsController.tableView.reloadData()
        } else {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = searchText
            
            guard let location: CLLocation = self.locationManager.location else { return }
            
            request.region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 2)
            )
            
            if self.localSearch != nil {
                self.localSearch.cancel()
            }
            self.localSearch = MKLocalSearch(request: request)
            self.localSearch.start(completionHandler: { (response: MKLocalSearch.Response?, error: Error?) in
                if let response = response {
                    self.searchResultsController.dataSource = response.mapItems
                    
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.searchResultsController.tableView.reloadData()
                    }
                }
            })
        }
    }
}

// MARK: - UISearchBarDelegate

extension LocationPickerViewController: UISearchBarDelegate {
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        debugPrint(#function)
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        debugPrint(#function)
    }
    
}

// MARK: - CLLocationManagerDelegate

extension LocationPickerViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        debugPrint(#function, error)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .restricted:
            break
        case .denied:
            break
        case .authorizedAlways:
            manager.startUpdatingLocation()
        case .authorizedWhenInUse:
            manager.startUpdatingLocation()
        @unknown default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let currentLocation: CLLocation = locations.last else { return }
        debugPrint(#function, currentLocation)
        
        if currentLocation.horizontalAccuracy < 100.0 {
            manager.stopUpdatingLocation()
        }
        
        if !self.didZoomToUserLocation {
            self.didZoomToUserLocation.toggle()
            
            let region = MKCoordinateRegion(
                center: currentLocation.coordinate,
                latitudinalMeters: radius,
                longitudinalMeters: radius
            )
            
            self.mapView.setRegion(region, animated: true)
        }
        
        /* let mapItem: MKMapItem = MKMapItem.forCurrentLocation()
        debugPrint(#function, mapItem.name) */
        
        let request = MKLocalSearch.Request()
        request.pointOfInterestFilter = .includingAll
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(center: currentLocation.coordinate, latitudinalMeters: radius, longitudinalMeters: radius)
        
        if self.localSearch != nil {
            self.localSearch.cancel()
        }
        self.localSearch = MKLocalSearch(request: request)
        
        self.localSearch.start { (response: MKLocalSearch.Response?, error: Error?) in
            if let response = response {
                self.dataSource = response.mapItems.map({ LocationMapItem($0) })
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.tableView.reloadData()
                }
            }
        }
    }
    
}

// MARK: - MKMapViewDelegate

extension LocationPickerViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation { return nil }
        
        let pinAnnotation = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "annotation")
        pinAnnotation.animatesDrop = true
        pinAnnotation.leftCalloutAccessoryView = self.calloutAccessoryView
        pinAnnotation.canShowCallout = true
        return pinAnnotation
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if let selectedMapItem = self.selectedMapItem {
            self.delegate?.locationPicker(self, didSelect: selectedMapItem)
        }
    }
    
}

// MARK: - UITableViewDelegate, UITableViewDataSource

extension LocationPickerViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataSource.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LocationPickerTableViewCell", for: indexPath) as! LocationPickerTableViewCell
        let mapItem: LocationMapItem = self.dataSource[indexPath.row]
        cell.textLabel?.text = mapItem.name
        cell.detailTextLabel?.text = mapItem.title
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return NSLocalizedString("nearby_places", comment: "")
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let mapItem: LocationMapItem = self.dataSource[indexPath.row]
        self.selectMapItem(mapItem)
    }
    
}

// MARK: - LocationSearchResultsControllerDelegate

extension LocationPickerViewController: LocationSearchResultsControllerDelegate {
    func locationSearchController(_ locationSearchController: LocationPickerSearchResultsTableViewController, didSelect mapItem: LocationMapItem) {
        locationSearchController.dismiss(animated: true, completion: nil)
        self.selectMapItem(mapItem, addToList: true)
    }
}
