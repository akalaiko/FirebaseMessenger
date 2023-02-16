//
//  DatabaseManager.swift
//  FirebaseMessenger
//
//  Created by Tim on 03.01.2023.
//

import Foundation
import UIKit
import FirebaseDatabase
import MessageKit

final class DatabaseManager {
    
    static let shared = DatabaseManager()
    
    private let database = Database.database().reference()
    
    public typealias completionBlock = (Result<String, Error>) -> Void
    
    static func safeEmail(email: String) -> String {
        var safeEmail = email.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    
    static func getProfilePicturePath(email: String) -> String {
        return "images/" + safeEmail(email: email) + "_profile_picture.png"
    }
}

// MARK: - Sending messages / conversations

/*
 "uniqueId" {
 "messages": [
 {
 "id": String,
 "kind": text, photo, video,
 "content": String,
 "date": Date (),
 "sender_email": String,
 "isRead": true/false,
 }
 ]
 }
 
 conversation =>
 [
 [
 "conversation_id": "uniqueId"
 "other_user_email":
 "name":
 "latest_message": => {
 "date": Date()
 "latest_message": "message"
 "is_read": true/false
 }
 ]
 ]
 */

extension DatabaseManager {
    
    /// Creates a new conversation with target user email and first message sent
    public func createNewConversation(with otherUserEmail: String, name: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String,
              let currentName = UserDefaults.standard.value(forKey: "name") as? String
        else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(email: currentUserEmail)
        
        let ref = database.child(safeEmail)
        ref.observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard var userNode = snapshot.value as? [String: Any] else {
                completion(false)
                return
            }
            
            let messageDateString = ChatViewController.dateFormatter.string(from: firstMessage.sentDate)
            
            var message = ""
            
            switch firstMessage.kind {
                
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(_):
                //                if let targetUrlString = mediaItem.url?.absoluteString {
                //                    message = targetUrlString
                //                }
                break
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            
            let conversationId = "conversation_\(firstMessage.messageId)"
            
            let newConversationData: [String: Any] = [
                "id": conversationId,
                "other_user_email": otherUserEmail,
                "name": name,
                "latest_message": [
                    "date": messageDateString,
                    "message": message,
                    "is_read": false
                ]
            ]
            
            let recipient_newConversationData: [String: Any] = [
                "id": conversationId,
                "other_user_email": safeEmail,
                "name": currentName,
                "latest_message": [
                    "date": messageDateString,
                    "message": message,
                    "is_read": false
                ]
            ]
            // update recipient conversation entry
            
            self?.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: { [weak self] snapshot in
                if var conversations = snapshot.value as? [[String: Any]] {
                    conversations.append(recipient_newConversationData)
                    self?.database.child("\(otherUserEmail)/conversations").setValue(conversations)
                } else {
                    self?.database.child("\(otherUserEmail)/conversations").setValue([recipient_newConversationData])
                }
                
                ref.setValue(userNode, withCompletionBlock: { [weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(name: name, id: conversationId, firstMessage: firstMessage, completion: completion)
                })
            })
            
            
            // update current user conversation entry
            
            if var conversations = userNode["conversations"] as? [[String: Any]] {
                conversations.append(newConversationData)
                userNode["conversations"] = conversations
            } else {
                userNode["conversations"] = [newConversationData]
            }
            
            ref.setValue(userNode, withCompletionBlock: { [weak self] error, _ in
                guard error == nil else {
                    completion(false)
                    return
                }
                self?.finishCreatingConversation(name: name, id: conversationId, firstMessage: firstMessage, completion: completion)
            })
        })
    }
    
    private func finishCreatingConversation(name: String, id: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else { return }
        let safeEmail = DatabaseManager.safeEmail(email: currentUserEmail)
        var content = ""
        let messageDateString = ChatViewController.dateFormatter.string(from: firstMessage.sentDate)
        
        switch firstMessage.kind {
            
        case .text(let messageText):
            content = messageText
        case .attributedText(_):
            break
        case .photo(_):
            //            if let targetUrlString = mediaItem.url?.absoluteString {
            //                content = targetUrlString
            //            }
            break
        case .video(_):
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }
        
        let message: [String: Any] = [
            "id": firstMessage.messageId,
            "kind": firstMessage.kind.description,
            "content": content,
            "date": messageDateString,
            "sender_email": safeEmail,
            "is_read": false,
            "name": name
        ]
        
        let value: [String: Any] = [
            "messages": [message]
        ]
        
        database.child(id).setValue(value, withCompletionBlock: { error, _ in
            guard error == nil else {
                completion(false)
                return
            }
            completion(true)
        })
    }
    
    /// Fetches and returns all conversations for the user with passed in email
    public func getAllConversations(for email: String, completion: @escaping (Result<[Conversation], Error>) -> Void) {
        print("\(email)/conversations")
        database.child("\(email)/conversations").observe(.value, with: { snapshot in
            print("trying to get all convos in database manager: ", snapshot.value)
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            print("passed the guard")
            print(value)
            let conversations: [Conversation] = value.compactMap({ dictionary in
                guard let id = dictionary["id"] as? String,
                      let name = dictionary["name"] as? String,
                      let otherUserEmail = dictionary["other_user_email"] as? String,
                      let latestMessage = dictionary["latest_message"] as? [String: Any],
                      let date = latestMessage["date"] as? String,
                      let message = latestMessage["message"] as? String,
                      let isRead = latestMessage["is_read"] as? Bool
                else {
                    return nil
                }
                print("we passed all shit for it")
                let latestMessageObject = LatestMessage(date: date, text: message, isRead: isRead)
                return Conversation(id: id, name: name, otherUserEmail: otherUserEmail, latestMessage: latestMessageObject)
            })
            print("got convos", conversations)
            completion(.success(conversations))
        })
    }
    
    /// Gets all messages for a given conversation
    public func getAllMessagesForConversation(with id: String, completion: @escaping (Result<[Message], Error>) -> Void) {
        database.child("\(id)/messages").observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            
            let messages: [Message] = value.compactMap({dictionary in
                guard let id = dictionary["id"] as? String,
                      let name = dictionary["name"] as? String,
                      let otherUserEmail = dictionary["sender_email"] as? String,
                      let content = dictionary["content"] as? String,
                      let dateString = dictionary["date"] as? String,
                      let isRead = dictionary["is_read"] as? Bool,
                      let kind = dictionary["kind"] as? String,
                      let date = ChatViewController.dateFormatter.date(from: dateString)
                else {
                    return nil
                }
                let sender = Sender(senderId: otherUserEmail, displayName: name, photoURL: "")
                
                var kindInput: MessageKind?
                
                switch kind {
                case "photo":
                    guard let url = URL(string: content),
                          let placeholder = UIImage(systemName: "photo") else { return nil }
                    
                    let media = Media(url: url, placeholderImage: placeholder, size: CGSize(width: 200, height: 200))
                    kindInput = .photo(media)
                case "video":
                    guard let url = URL(string: content),
                          let placeholder = UIImage(systemName: "video") else { return nil }
                    
                    let media = Media(url: url, placeholderImage: placeholder, size: CGSize(width: 200, height: 200))
                    kindInput = .video(media)
                case "text":
                    kindInput = .text(content)
                default:
                    break
                }
                guard let kindInput else { return nil }
                return Message(sender: sender, messageId: id, sentDate: date, kind: kindInput)
            })
            
            completion(.success(messages))
        })
    }
    
    /// Sends a message with target conversation and message
    public func sendMessage(to conversation: String, otherUserEmail: String, name: String, message: Message, completion: @escaping (Bool) -> Void) {
        
        guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String else { return }
        let safeEmail = DatabaseManager.safeEmail(email: currentUserEmail)
        var content = ""
        let messageDateString = ChatViewController.dateFormatter.string(from: message.sentDate)
        
        switch message.kind {
            
        case .text(let messageText):
            content = messageText
        case .attributedText(_):
            break
        case .photo(let mediaItem):
            if let targetUrlString = mediaItem.url?.absoluteString {
                content = targetUrlString
            }
            break
        case .video(let mediaItem):
            if let targetUrlString = mediaItem.url?.absoluteString {
                content = targetUrlString
            }
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }
        
        //add new message to messages
        database.child("\(conversation)/messages").observeSingleEvent(of: .value, with: { [weak self] snapshot in
            
            guard let self else { return }
            guard var currentMessages = snapshot.value as? [[String: Any]] else {
                completion(false)
                return
            }
            
            let newMessage: [String: Any] = [
                "id": message.messageId,
                "kind": message.kind.description,
                "content": content,
                "date": messageDateString,
                "sender_email": safeEmail,
                "is_read": false,
                "name": name
            ]
            
            print(newMessage)
            
            currentMessages.append(newMessage)
            
            self.database.child("\(conversation)/messages").setValue(currentMessages) { error, _ in
                guard error == nil else {
                    print(error)
                    completion(false)
                    return
                }
                
                self.database.child("\(safeEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                    var databaseEntryConversations = [[String: Any]]()
                    
                    let updatedValue: [String: Any] = [
                        "date": messageDateString,
                        "message": content,
                        "is_read": false
                    ]
                    
                    if var currentUserConversations = snapshot.value as? [[String: Any]] {
                        var targetConversation: [String: Any]?
                        var position = 0
                        for currentUserConversation in currentUserConversations {
                            if let currentId = currentUserConversation["id"] as? String, currentId == conversation {
                                targetConversation = currentUserConversation
                                break
                            }
                            position += 1
                        }
                        
                        if var targetConversation {
                            targetConversation["latest_message"] = updatedValue
                            currentUserConversations[position] = targetConversation
                            databaseEntryConversations = currentUserConversations
                        } else {
                            let newConversationData: [String: Any] = [
                                "id": conversation,
                                "other_user_email": DatabaseManager.safeEmail(email: otherUserEmail),
                                "name": name,
                                "latest_message": updatedValue
                            ]
                            currentUserConversations.append(newConversationData)
                            databaseEntryConversations = currentUserConversations
                        }
                    } else {
                        let newConversationData: [String: Any] = [
                            "id": conversation,
                            "other_user_email": DatabaseManager.safeEmail(email: otherUserEmail),
                            "name": name,
                            "latest_message": updatedValue
                        ]
                        databaseEntryConversations = [
                            newConversationData
                        ]
                    }
                    
                    self.database.child("\(safeEmail)/conversations").setValue(databaseEntryConversations, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            print("failed to write to database")
                            completion(false)
                            return
                        }
                        
                        // update latest message for recipient
                        
                        self.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
                            
                            guard let currentUserName = UserDefaults.standard.value(forKey: "name") as? String else {
                                print("emotional damage")
                                return }
                            var otherUserDatabaseEntryConversations = [[String: Any]]()
                            
                            if var otherUserConversations = snapshot.value as? [[String: Any]] {
                                
                                var targetConversation: [String: Any]?
                                var position = 0
                                for otherUserConversation in otherUserConversations {
                                    if let currentId = otherUserConversation["id"] as? String, currentId == conversation {
                                        targetConversation = otherUserConversation
                                        break
                                    }
                                    position += 1
                                }
                                
                                if var targetConversation {
                                    targetConversation["latest_message"] = updatedValue
                                    otherUserConversations[position] = targetConversation
                                    otherUserDatabaseEntryConversations = otherUserConversations
                                    
                                } else {
                                    let newConversationData: [String: Any] = [
                                        "id": conversation,
                                        "other_user_email": safeEmail,
                                        "name": currentUserName,
                                        "latest_message": updatedValue
                                    ]
                                    
                                    otherUserConversations.append(newConversationData)
                                    otherUserDatabaseEntryConversations = otherUserConversations
                                }
                            } else {
                                let newConversationData: [String: Any] = [
                                    "id": conversation,
                                    "other_user_email": safeEmail,
                                    "name": currentUserName,
                                    "latest_message": updatedValue
                                ]
                                otherUserDatabaseEntryConversations = [
                                    newConversationData
                                ]
                            }
                            
                            
                            self.database.child("\(otherUserEmail)/conversations").setValue(otherUserDatabaseEntryConversations, withCompletionBlock: { error, _ in
                                guard error == nil else {
                                    print("failed to write to database")
                                    completion(false)
                                    return
                                }
                                
                                completion(true)
                            })
                        })
                    })
                })
            }
        })
    }
    
}

// MARK: - Account Managment

extension DatabaseManager {
    
    public func userExists(with email: String, completion: @escaping ((Bool) -> Void)) {
        
        let safeEmail = DatabaseManager.safeEmail(email: email)
        
        database.child(safeEmail).observeSingleEvent(of: .value, with: { snapshot in
            guard snapshot.value as? [String: Any] != nil else {
                print("user doesn't exist")
                completion(false)
                return
            }
            print("user exists")
            completion(true)
        })
    }
    
    public func insertUser(with user: ChatAppUser, completion: @escaping (Bool) -> Void) {
        
        database.child(user.safeEmail).setValue([
            "first_name" : user.firstName,
            "last_name" : user.lastName
        ], withCompletionBlock: { [weak self] error, _ in
            guard let self else { return }
            guard error == nil else {
                print("failed to write to database")
                completion(false)
                return
            }
            
            self.database.child("users").observeSingleEvent(of: .value, with: { snapshot in
                if var usersCollection = snapshot.value as? [[String: String]] {
                    // append to it
                    let newElement = [
                        "name": user.fullName,
                        "email": user.safeEmail
                    ]
                    usersCollection.append(newElement)
                    
                    self.database.child("users").setValue(usersCollection, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                    
                } else {
                    //create it
                    let newCollection: [[String: String]] = [
                        [
                            "name": user.fullName,
                            "email": user.safeEmail
                        ]
                    ]
                    
                    self.database.child("users").setValue(newCollection, withCompletionBlock: { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    })
                }
            })
        })
    }
    
    public func getAllUsers(completion: @escaping (Result<[[String: String]], Error>) -> Void) {
        database.child("users").observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [[String: String]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        })
    }
    
    public enum DatabaseError: Error {
        case failedToFetch
    }
}

extension DatabaseManager {
    public func getDataFor(path: String, completion: @escaping (Result<Any, Error>) -> Void) {
        database.child(path).observeSingleEvent(of: .value, with: { snapshot in
            guard let value = snapshot.value else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        })
    }
    
    public func deleteConversation(id: String, completion: @escaping (Bool) -> Void) {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else { return }
        let safeEmail = DatabaseManager.safeEmail(email: email)
        
        let ref = database.child("\(safeEmail)/conversations")
        ref.observeSingleEvent(of: .value, with: { [weak self] snapshot in
            guard var conversations = snapshot.value as? [[String: Any]] else {
                completion(false)
                return
            }
            for (index, conversation) in conversations.enumerated() {
                guard let conversationId = conversation["id"] as? String else { return }
                if conversationId == id {
                    conversations.remove(at: index)
                    break
                }
            }
            
            ref.setValue(conversations, withCompletionBlock: { error, _ in
                guard error == nil else {
                    completion(false)
                    return
                }
                completion(true)
            })
            
        })
    }
    func conversationExists(with otherUserEmail: String, completion: @escaping completionBlock) {
        guard let senderEmail = UserDefaults.standard.value(forKey: "email") as? String else { return }
        let safeSenderEmail = DatabaseManager.safeEmail(email: senderEmail)
        let safeOtherUserEmail = DatabaseManager.safeEmail(email: otherUserEmail)
        
        database.child("\(safeOtherUserEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
            guard let collection = snapshot.value as? [[String: Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            if let existingConversation = collection.first(where: {
                guard let targetSenderEmail = $0["other_user_email"] as? String else { return false }
                return safeSenderEmail == targetSenderEmail
            }) {
                guard let id = existingConversation["id"] as? String else {
                    completion(.failure(DatabaseError.failedToFetch))
                    return
                }
                completion(.success(id))
                return
            }
            completion(.failure(DatabaseError.failedToFetch))
            return
        })
    }
    
}


struct ChatAppUser {
    
    let firstName: String
    let lastName: String
    let emailAddress: String
    
    var fullName: String {
        return firstName + " " + lastName
    }
    
    var safeEmail: String {
        var email = emailAddress.replacingOccurrences(of: ".", with: "-")
        email = email.replacingOccurrences(of: "@", with: "-")
        return email
    }
    
    var profilePictureFileName: String {
        return "\(safeEmail)_profile_picture.png"
    }
}

