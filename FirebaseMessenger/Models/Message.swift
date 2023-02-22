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
        case .text(_):
            return "text"
        case .attributedText(_):
            return "attributed_text"
        case .photo(_):
            return "photo"
        case .video(_):
            return "video"
        case .location(_):
            return "location"
        case .emoji(_):
            return "emoji"
        case .audio(_):
            return "audio"
        case .contact(_):
            return "contact"
        case .linkPreview(_):
            return "link_preview"
        case .custom(_):
            return "custom"
        }
    }
}
