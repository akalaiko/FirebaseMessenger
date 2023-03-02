//
//  Location.swift
//  FirebaseMessenger
//
//  Created by Tim on 22.02.2023.
//

import CoreLocation
import MessageKit

struct Location: LocationItem {
    var location: CLLocation
    var size: CGSize
}
