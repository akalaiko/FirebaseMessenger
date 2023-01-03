//
//  ViewController.swift
//  FirebaseMessenger
//
//  Created by Tim on 28.12.2022.
//

import UIKit
import FirebaseAuth 

class ConversationsViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.backgroundColor = .red
        validateAuth()

    }
    
    private func validateAuth() {
        print("CHECK")
        if FirebaseAuth.Auth.auth().currentUser == nil {
            let vc = LoginViewController()
            navigationController?.pushViewController(vc, animated: false)
        }
    }


}

