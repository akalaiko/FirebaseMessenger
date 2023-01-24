//
//  TabBar.swift
//  FirebaseMessenger
//
//  Created by Tim on 19.01.2023.
//

import UIKit

class TabBar: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupVCs()
    }
    
    func setupVCs() {
        viewControllers = [
            createNavController(for: ConversationsViewController(), title: "Chats", image: "clock.fill"),
            createNavController(for: ProfileViewViewController(), title: "Profile", image: "arrow.up.heart.fill")
        ]
    }
    
    fileprivate func createNavController(for rootViewController: UIViewController,
                                         title: String,
                                         image: String) -> UIViewController {
        let navController = UINavigationController(rootViewController: rootViewController)
        navController.tabBarItem.title = title
        navController.tabBarItem.image = UIImage(systemName: image)
        navController.navigationBar.prefersLargeTitles = true
        rootViewController.navigationItem.title = title
        return navController
    }
}
