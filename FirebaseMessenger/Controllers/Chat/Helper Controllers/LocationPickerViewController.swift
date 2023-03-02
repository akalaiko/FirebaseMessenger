//
//  LocationPickerViewController.swift
//  FirebaseMessenger
//
//  Created by Tim on 18.02.2023.
//

import CoreLocation
import MapKit
import UIKit

final class LocationPickerViewController: UIViewController {
    
    public var completion: ((CLLocationCoordinate2D) -> Void)?
    
    private let locationManager = CLLocationManager()
    private var coordinates: CLLocationCoordinate2D?
    private var isPickable = true
    private let map: MKMapView = {
        let map = MKMapView()
        map.isUserInteractionEnabled = true
        return map
    }()
    
    init(coordinates: CLLocationCoordinate2D? = nil) {
        super.init(nibName: nil, bundle: nil)
        self.coordinates = coordinates
        self.isPickable = coordinates == nil
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.addSubview(map)
        locationManager.delegate = self
        if isPickable {
            title = "Pick location"
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Send", style: .done, target: self, action: #selector(sendButtonTapped))
            let gesture = UITapGestureRecognizer(target: self, action: #selector(didTapMap(_:)))
            map.addGestureRecognizer(gesture)
            
            locationManager.requestWhenInUseAuthorization()
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.distanceFilter = kCLDistanceFilterNone
            locationManager.startUpdatingLocation()
            map.showsUserLocation = true
        } else {
            title = "Location"
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Close", style: .done, target: self, action: #selector(dismissSelf))
            if let coordinates {
                let pin = MKPointAnnotation()
                pin.coordinate = coordinates
                map.addAnnotation(pin)
                map.camera = MKMapCamera(lookingAtCenter: coordinates, fromEyeCoordinate: coordinates, eyeAltitude: 2000)
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        map.frame = view.bounds
    }
    
    @objc private func sendButtonTapped(){
        guard let coordinates else { return }
        completion?(coordinates)
        dismiss(animated: true)
    }
    
    @objc private func didTapMap(_ gesture: UITapGestureRecognizer) {
        guard isPickable else { return }
        let locationInView = gesture.location(in: map)
        coordinates = map.convert(locationInView, toCoordinateFrom: map)
        guard let coordinates else { return }
        map.removeAnnotations(map.annotations)
        let pin = MKPointAnnotation()
        pin.coordinate = coordinates
        map.addAnnotation(pin)
    }
    
    @objc private func dismissSelf() {
        dismiss(animated: true)
    }
}

extension LocationPickerViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let userLocation = locations.first?.coordinate {
            print(userLocation)
            map.camera = MKMapCamera(lookingAtCenter: userLocation, fromEyeCoordinate: userLocation, eyeAltitude: 2000)
            manager.stopUpdatingLocation()
        }
    }
}


