//
//  Message.swift
//  FirebaseMessenger
//
//  Created by Tim on 22.02.2023.
//

import Foundation
import MessageKit

struct Message: MessageType{
    var sender: SenderType
    var messageId: String
    var sentDate: Date
    var kind: MessageKind
}

extension MessageKind {
    var description: String {
        switch self {
        case .text:
            return "text"
        case .photo:
            return "photo"
        case .video:
            return "video"
        case .location:
            return "location"
        default:
            return "custom"
        }
    }
}
