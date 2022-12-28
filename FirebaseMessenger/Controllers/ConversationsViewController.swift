//
//  ViewController.swift
//  FirebaseMessenger
//
//  Created by Tim on 28.12.2022.
//

import UIKit

class ConversationsViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.backgroundColor = .red
        
        let isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
        
        if !isLoggedIn {
            let vc = LoginViewController()
            navigationController?.modalPresentationStyle = .fullScreen
            navigationController?.pushViewController(vc, animated: false)
//            present(vc, animated: false)
        }
    }


}

