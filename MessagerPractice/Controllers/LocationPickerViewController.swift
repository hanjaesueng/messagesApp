//
//  LocationPickerViewController.swift
//  MessagerPractice
//
//  Created by 김현미 on 2022/02/26.
//

import UIKit
import MapKit
import CoreLocation

final class LocationPickerViewController: UIViewController {

    public var completion : ((CLLocationCoordinate2D) -> Void)?
    
    private var mPin : MKPointAnnotation?
    private var coordinate : CLLocationCoordinate2D?
    private var isPickable = true
    private let map : MKMapView = {
        let map = MKMapView()
        return map
    }()
    init(coordinates : CLLocationCoordinate2D?) {
        self.coordinate = coordinates
        isPickable = coordinates == nil
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if isPickable {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Send", style: .done, target: self, action: #selector(sendButtonTapped))
            map.isUserInteractionEnabled = true
            let gesture = UITapGestureRecognizer(target: self, action: #selector(tapMap(_:)))
            gesture.numberOfTapsRequired = 1
            gesture.numberOfTouchesRequired = 1
            map.addGestureRecognizer(gesture)
        } else {
            guard let coordinate = coordinate else {
                return
            }
            
            let pin = MKPointAnnotation()
            pin.coordinate = coordinate
            map.addAnnotation(pin)
            mPin = pin
        }
        
        view.addSubview(map)
        
        
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        map.frame = view.bounds
        
    }

    @objc func sendButtonTapped(){
        guard let coordinate = coordinate else {return}
        
        navigationController?.popToRootViewController(animated: true)
        completion?(coordinate)
    }

    @objc func tapMap(_ gesture : UITapGestureRecognizer){
        let locationInView = gesture.location(in: map)
        let coordinates = map.convert(locationInView, toCoordinateFrom: map)
        coordinate = coordinates
        
        // drop a pin on that location
        if mPin == nil {
            let pin = MKPointAnnotation()
            pin.coordinate = coordinates
            map.addAnnotation(pin)
            mPin = pin
        } else {
            mPin?.coordinate = coordinates
        }
         
        
    }
}
