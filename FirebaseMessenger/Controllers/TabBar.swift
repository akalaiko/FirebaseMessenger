//
//  TabBar.swift
//  FirebaseMessenger
//
//  Created by Tim on 19.01.2023.
//

import UIKit
//
//class TabBar: UITabBarController {
//    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        view.backgroundColor = .systemBackground
//           UITabBar.appearance().barTintColor = .systemBackground
//           tabBar.tintColor = .label
//           setupVCs()
//    }
//    
//    func setupVCs() {
//            viewControllers = [
//                createNavController(for: ConversationsViewController(), title: NSLocalizedString("Conversations", comment: ""), image: UIImage(systemName: "clock.fill")!),
//                createNavController(for: ViewController(), title: NSLocalizedString("Popular", comment: ""), image: UIImage(systemName: "arrow.up.heart.fill")!)
//            ]
//    }
//    
//    fileprivate func createNavController(for rootViewController: UIViewController,
//                                                      title: String,
//                                                      image: UIImage) -> UIViewController {
//            let navController = UINavigationController(rootViewController: rootViewController)
//            navController.tabBarItem.title = title
//            navController.tabBarItem.image = image
//            navController.navigationBar.prefersLargeTitles = true
//            rootViewController.navigationItem.title = title
//            return navController
//        }
//    
//}
