//
//  LocationMapItem.swift
//  LocationPicker
//
//  Created by Idan Moshe on 30/01/2021.
//

import UIKit
import MapKit

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
