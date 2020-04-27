//
//  ViewController.swift
//  GoogleDriveManualTest
//
//  Created by Philipp Schmid on 27.04.20.
//  Copyright © 2020 Skymatic GmbH. All rights reserved.
//

import UIKit
import CloudAccessPrivate
import Promises
class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        let authentication = GoogleDriveCloudAuthentication()
        authentication.isAuthenticated().then{ authenticated in
            if authenticated{
                return Promise(())
            } else {
                return authentication.authenticate(from: self)
            }
        }.then{
            print("authenticated")
        }.catch{ error in
            print("error: \(error)")
        }
    }


}

