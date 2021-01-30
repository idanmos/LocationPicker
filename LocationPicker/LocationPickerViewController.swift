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

// MARK: - Protocol LocationPickerViewControllerDelegate

protocol LocationPickerViewControllerDelegate: class {
    func locationPickerOnPressCloseButtonItem(_ locationPicker: LocationPickerViewController)
    func locationPickerOnPressRefreshButtonItem(_ locationPicker: LocationPickerViewController)
    func locationPicker(_ locationPicker: LocationPickerViewController, didFailWithError error: Error)
    func locationPicker(_ locationPicker: LocationPickerViewController, didSelect mapItem: LocationMapItem)
}

// MARK: - LocationPickerViewController

class LocationPickerViewController: UIViewController {
    
    // MARK: - Outlets
    
    @IBOutlet private weak var mapView: MKMapView!
    @IBOutlet private weak var tableView: UITableView!
    
    // MARK: - Properties
    
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
    
    // MARK: - Lifecycle
    
    deinit {
        debugPrint("Deallocating \(self)")
        self.dataSource.removeAll()
        self.mapView.delegate = nil
        self.locationManager.stopUpdatingLocation()
        self.locationManager.delegate = nil
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
    
    func makeRefresh() {
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

// MARK: - Action Handlers

extension LocationPickerViewController {
    
    @objc private func onPressCloseButtonItem(_ sender: Any) {
        self.delegate?.locationPickerOnPressCloseButtonItem(self)
    }
    
    @objc private func onPressRefreshButtonItem(_ sender: Any) {
        self.delegate?.locationPickerOnPressRefreshButtonItem(self)
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
        self.delegate?.locationPicker(self, didFailWithError: error)
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
