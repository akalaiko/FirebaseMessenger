//
//  User.swift
//  FirebaseMessenger
//
//  Created by Tim on 22.02.2023.
//

import Foundation

struct User {
    
    let firstName: String
    let lastName: String
    let emailAddress: String
    
    var fullName: String { firstName + " " + lastName }
    
    var safeEmail: String {
        var email = emailAddress.replacingOccurrences(of: ".", with: "-")
        email = email.replacingOccurrences(of: "@", with: "-")
        return email
    }
    
    var profilePictureFileName: String {
        return "\(safeEmail)_profile_picture.png"
    }
}
