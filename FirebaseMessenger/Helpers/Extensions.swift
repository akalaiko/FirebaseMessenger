//
//  Extensions.swift
//  FirebaseMessenger
//
//  Created by Tim on 28.12.2022.
//

import UIKit

extension UIView {
    
    var width: CGFloat { frame.size.width }
    var height: CGFloat { frame.size.height }
    var top: CGFloat { frame.origin.y }
    var bottom: CGFloat { top + height }
    var left: CGFloat { frame.origin.x }
    var right: CGFloat { left + width }
}

extension Notification.Name {
    /// Notification when user logs in
    static let didLogInNotification = Notification.Name("didLogInNotification")
}
