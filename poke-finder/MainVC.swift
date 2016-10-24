//
//  ViewController.swift
//  poke-finder
//
//  Created by Jason Ngo on 2016-10-22.
//  Copyright © 2016 Jason Ngo. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import FirebaseDatabase

class MainVC: UIViewController {
    
    @IBOutlet weak var pokeballBtn: UIButton!
    @IBOutlet weak var mapView: MKMapView!
    
    let locationManger = CLLocationManager()
    var geoFire: GeoFire!
    var geoFireRef: FIRDatabaseReference!
    var initialLaunch = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.delegate = self;
        mapView.userTrackingMode = MKUserTrackingMode.follow
        
        locationManger.delegate = self
        
        geoFireRef = FIRDatabase.database().reference()
        geoFire = GeoFire(firebaseRef: geoFireRef)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            mapView.showsUserLocation = true
        } else {
            locationManger.requestWhenInUseAuthorization()
        }
    }

    func createSighting(forLocation location: CLLocation, withPokemon pokemonID: Int) {
        geoFire.setLocation(location, forKey: "\(pokemonID)")
    }
    
    func showSightingsOnMap(location: CLLocation) {
        let center = CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        let circleQuery = geoFire.query(at: center, withRadius: 2.5)
        
        _ = circleQuery?.observe(GFEventType.keyEntered, with: { (key, location) in
            
            if let key = key, let location = location {
                let annotation = PokeAnnotation(coordinate: location.coordinate, pokeID: Int(key)!)
                
                self.mapView.addAnnotation(annotation)
            }
        })
    }
    
    @IBAction func pokemonSpotted(_ sender: AnyObject) {
        let location = CLLocation(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude)
        
        let randomNumber = arc4random_uniform(150) + 1
        createSighting(forLocation: location, withPokemon: Int(randomNumber))
    }
}

extension MainVC: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        if let location = userLocation.location {
            if !initialLaunch {
                centerMapOnLocation(location: location)
                initialLaunch = true
            }
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {

        guard !annotation.isKind(of: MKUserLocation.self) else {
            return nil
        }
        
        let annotationID = "Pokemon"
        var annotationView: MKAnnotationView?
        
        if let dequeueAnnotationView = mapView.dequeueReusableAnnotationView(withIdentifier: annotationID) {
            annotationView = dequeueAnnotationView
            annotationView?.annotation = annotation
        } else {
            let av = MKAnnotationView(annotation: annotation, reuseIdentifier: annotationID)
            av.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
            annotationView = av
        }
        
        if let annotationView = annotationView, let anno = annotation as? PokeAnnotation {
            annotationView.canShowCallout = true
            annotationView.image = UIImage(named: "\(anno.pokeID)")
            let mapButton = UIButton()
            mapButton.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
            mapButton.setImage(UIImage(named: "map"), for: .normal)
            annotationView.rightCalloutAccessoryView = mapButton
        }
        
        return annotationView
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if let anno = view.annotation as? PokeAnnotation {
            
            var place: MKPlacemark!
            if #available(iOS 10.0, *) {
                place = MKPlacemark(coordinate: anno.coordinate)
            } else {
                place = MKPlacemark(coordinate: anno.coordinate, addressDictionary: nil)
            }
            let destination = MKMapItem(placemark: place)
            destination.name = "Pokemon Sighting"
            let regionDistance: CLLocationDistance = 1000
            let regionSpan = MKCoordinateRegionMakeWithDistance(anno.coordinate, regionDistance, regionDistance)
            
            let options = [MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: regionSpan.center), MKLaunchOptionsMapSpanKey:  NSValue(mkCoordinateSpan: regionSpan.span), MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving] as [String : Any]
            
            MKMapItem.openMaps(with: [destination], launchOptions: options)
        }
    }
    
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        let location = CLLocation(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude)
        showSightingsOnMap(location: location)
    }
    
    func centerMapOnLocation(location: CLLocation) {
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, 2000, 2000)
        mapView.setRegion(coordinateRegion, animated: true)
    }
}

extension MainVC: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse {
            mapView.showsUserLocation = true
        }
    }
}


