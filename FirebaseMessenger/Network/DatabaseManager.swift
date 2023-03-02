//
//  DatabaseManager.swift
//  FirebaseMessenger
//
//  Created by Tim on 03.01.2023.
//

import CoreLocation
import FirebaseDatabase
import MessageKit
import UIKit

final class DatabaseManager {
    
    static let shared = DatabaseManager()
    private init() {}
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .long
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()
    
    static func safeEmail(email: String?) -> String  {
        guard let email else { return "" }
        var safeEmail = email.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    
    static func getProfilePicturePath(email: String) -> String {
        return "images/" + safeEmail(email: email) + "_profile_picture.png"
    }
    
    private enum DatabaseError: Error {
        case failed
    }
    private lazy var database = Database.database().reference()
    private lazy var senderEmail = UserDefaults.standard.value(forKey: "email") as? String
    
    typealias completionBlockForString = (Result<String, Error>) -> Void
    
}

// MARK: - Sending messages / conversations

extension DatabaseManager {
    
    /// Creates a new conversation with target user email and first message sent
    public func createNewConversation(with otherUserEmail: String, name: String, firstMessage: Message, completion: @escaping (Bool) -> Void) {
        
        let conversationId = "conversation_\(firstMessage.messageId)"
        let newMessage: [String: Any] = [:]
        let newConversation: [String: Any] = ["messages" : newMessage]
        
        database.child("conversations/\(conversationId)").setValue(newConversation) { [weak self] error, _ in
            guard error == nil else { return completion(false) }
            self?.sendMessage(to: conversationId, otherUserEmail: otherUserEmail, name: name, message: firstMessage) { success in
                return completion(success)
            }
        }
    }
    
    /// Fetches and returns all conversations for the user with passed in email
    public func getAllConversations(for email: String, completion: @escaping (Result<[Conversation], Error>) -> Void) {
        database.child("users/\(email)/conversations").observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [[String: Any]] else { return completion(.failure(DatabaseError.failed)) }
            
            let conversations: [Conversation] = value.compactMap({ dictionary in
                guard let id = dictionary["id"] as? String,
                      let name = dictionary["name"] as? String,
                      let otherUserEmail = dictionary["other_user_email"] as? String,
                      let latestMessage = dictionary["latest_message"] as? [String: Any],
                      let date = latestMessage["date"] as? String,
                      let message = latestMessage["message"] as? String
                else {
                    return nil
                }
                let latestMessageObject = LatestMessage(date: date, text: message)
                return Conversation(id: id, name: name, otherUserEmail: otherUserEmail, latestMessage: latestMessageObject)
            })
            completion(.success(conversations))
        })
    }
    
    /// Gets all messages for a given conversation
    public func getAllMessagesForConversation(with id: String, completion: @escaping (Result<[Message], Error>) -> Void) {
        database.child("conversations/\(id)/messages").observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [[String: Any]] else { return completion(.failure(DatabaseError.failed)) }
            
            let messages: [Message] = value.compactMap({ dictionary in
                guard let id = dictionary["id"] as? String,
                      let name = dictionary["name"] as? String,
                      let otherUserEmail = dictionary["sender_email"] as? String,
                      let content = dictionary["content"] as? String,
                      let dateString = dictionary["date"] as? String,
                      let kind = dictionary["kind"] as? String,
                      let date = DatabaseManager.dateFormatter.date(from: dateString)
                else {
                    return nil
                }
                
                let sender = Sender(senderId: otherUserEmail, displayName: name)
                var kindInput: MessageKind?
                
                switch kind {
                case "photo":
                    guard let url = URL(string: content),
                          let placeholder = UIImage(systemName: "photo") else { return nil }
                    let media = Media(url: url, placeholderImage: placeholder, size: CGSize(width: 200, height: 200))
                    kindInput = .photo(media)
                case "video":
                    guard let url = URL(string: content),
                          let placeholder = UIImage(named: "video_placeholder") else { return nil }
                    let media = Media(url: url, placeholderImage: placeholder, size: CGSize(width: 200, height: 200))
                    kindInput = .video(media)
                case "text":
                    kindInput = .text(content)
                case "location":
                    let coordinatesStrings = content.components(separatedBy: ",")
                    guard let latitude = Double(coordinatesStrings[0]), let longitude = Double(coordinatesStrings[1]) else { return nil }
                    let coordinates = CLLocation(latitude: latitude, longitude: longitude)
                    let locationItem = Location(location: coordinates, size: CGSize(width: 200, height: 200))
                    kindInput = .location(locationItem)
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
        guard let currentName = UserDefaults.standard.value(forKey: "name") as? String else { return }
        let safeEmail = DatabaseManager.safeEmail(email: senderEmail)
        var content = ""
        let messageDateString = DatabaseManager.dateFormatter.string(from: message.sentDate)
        
        switch message.kind {
            
        case .text(let messageText):
            content = messageText
        case .photo(let mediaItem):
            if let targetUrlString = mediaItem.url?.absoluteString { content = targetUrlString }
        case .video(let mediaItem):
            if let targetUrlString = mediaItem.url?.absoluteString { content = targetUrlString }
        case .location(let locationData):
            let location = locationData.location
            content = "\(location.coordinate.latitude),\(location.coordinate.longitude)"
        default:
            break
        }
        
        let latestMessageUpdatedValue: [String: Any] = [
            "date": messageDateString,
            "message": content
        ]
        
        let newMessage: [String: Any] = [
            "id": message.messageId,
            "kind": message.kind.description,
            "content": content,
            "date": messageDateString,
            "sender_email": safeEmail,
            "name": name
        ]
        
        let newConversationData: [String: Any] = [
            "id": conversation,
            "other_user_email": otherUserEmail,
            "name": name,
            "latest_message": latestMessageUpdatedValue
        ]
        
        let recipientNewConversationData: [String: Any] = [
            "id": conversation,
            "other_user_email": safeEmail,
            "name": currentName,
            "latest_message": latestMessageUpdatedValue
        ]
        
        database.child("conversations/\(conversation)/messages").observeSingleEvent(of: .value, with: { [weak self] snapshot in
            var updatedMessages = [[String: Any]]()
            if let existingMessages = snapshot.value as? [[String: Any]] {
                updatedMessages = existingMessages
                updatedMessages.append(newMessage)
            } else {
                updatedMessages = [newMessage]
            }
            
            self?.database.child("conversations/\(conversation)/messages").setValue(updatedMessages) { [weak self] error, _ in
                guard error == nil else { return completion(false) }
                
                let path = "users/\(safeEmail)/conversations"
                self?.database.child(path).observeSingleEvent(of: .value) { [weak self] snapshot in
                    var targetConversation = [String: Any]()
                    if var conversations = snapshot.value as? [[String: Any]] {
                        for (index, conversationEntry) in conversations.enumerated() where
                        conversationEntry["id"] as? String == conversation {
                            targetConversation = conversations[index]
                            targetConversation["latest_message"] = latestMessageUpdatedValue
                            conversations[index] = targetConversation
                            self?.database.child(path).setValue(conversations)
                            completion(true)
                            break
                        }
                        guard targetConversation.isEmpty else { return }
                        conversations.append(newConversationData)
                        self?.database.child(path).setValue(conversations)
                        completion(true)
                    } else {
                        self?.database.child(path).setValue([newConversationData])
                        completion(true)
                    }
                }
                
                let otherUserPath = "users/\(otherUserEmail)/conversations"
                self?.database.child(otherUserPath).observeSingleEvent(of: .value, with: { [weak self] snapshot in
                    var targetConversation = [String: Any]()
                    if var conversations = snapshot.value as? [[String: Any]] {
                        for (index, conversationEntry) in conversations.enumerated() where
                        conversationEntry["id"] as? String == conversation {
                            targetConversation = conversations[index]
                            targetConversation["latest_message"] = latestMessageUpdatedValue
                            conversations[index] = targetConversation
                            self?.database.child(otherUserPath).setValue(conversations)
                            completion(true)
                            break
                        }
                        guard targetConversation.isEmpty else { return }
                        conversations.append(recipientNewConversationData)
                        self?.database.child(otherUserPath).setValue(conversations)
                        completion(true)
                    } else {
                        self?.database.child(otherUserPath).setValue([recipientNewConversationData])
                        completion(true)
                    }
                })
            }
        })
    }
}

// MARK: - Account Managment

extension DatabaseManager {
    
    public func userExists(with email: String, completion: @escaping ((Bool) -> Void)) {
        let safeEmail = DatabaseManager.safeEmail(email: email)
        database.child("users/\(safeEmail)").observeSingleEvent(of: .value, with: { snapshot in
            return completion(snapshot.value as? [String: Any] != nil)
        })
    }
    
    public func insertUser(with user: User, completion: @escaping (Bool) -> Void) {
            let newElement = ["name": user.fullName, "email": user.safeEmail]
            
            database.child("users").observeSingleEvent(of: .value, with: { [weak self] snapshot in
                var newOrUpdatedCollection = [String: Any]()
                
                if let usersCollection = snapshot.value as? [String: Any] {
                    newOrUpdatedCollection = usersCollection
                }
                newOrUpdatedCollection[user.safeEmail] = newElement
                self?.database.child("users").setValue(newOrUpdatedCollection) { error, _ in
                    return completion(error == nil)
                }
            })
    }
    
    public func getAllUsers(completion: @escaping (Result<[String: Any], Error>) -> Void) {
        database.child("users").observe(.value, with: { snapshot in
            guard let value = snapshot.value as? [String: Any] else { return completion(.failure(DatabaseError.failed)) }
            completion(.success(value))
        })
    }
}

extension DatabaseManager {
    
    public func getDataFor(path: String, completion: @escaping (Result<Any, Error>) -> Void) {
        database.child(path).observeSingleEvent(of: .value, with: { snapshot in
            guard let value = snapshot.value else { return completion(.failure(DatabaseError.failed)) }
            completion(.success(value))
        })
    }
    
    public func deleteConversation(id: String, completion: @escaping (Bool) -> Void) {
        let safeEmail = DatabaseManager.safeEmail(email: senderEmail)
        let ref = database.child("users/\(safeEmail)/conversations")
        
        ref.observeSingleEvent(of: .value, with: { snapshot in
            guard var conversations = snapshot.value as? [[String: Any]] else { return completion(false) }
            for (index, conversation) in conversations.enumerated() {
                guard let conversationId = conversation["id"] as? String else { return }
                if conversationId == id {
                    conversations.remove(at: index)
                    break
                }
            }
            ref.setValue(conversations, withCompletionBlock: { error, _ in
                return completion(error == nil)
            })
        })
    }
    
    public func conversationExists(with otherUserEmail: String, completion: @escaping completionBlockForString) {
        let safeSenderEmail = DatabaseManager.safeEmail(email: senderEmail)
        let safeOtherUserEmail = DatabaseManager.safeEmail(email: otherUserEmail)
        
        database.child("users/\(safeOtherUserEmail)/conversations").observeSingleEvent(of: .value, with: { snapshot in
            guard let collection = snapshot.value as? [[String: Any]] else { return completion(.failure(DatabaseError.failed)) }
            
            if let existingConversation = collection.first( where: {
                guard let targetSenderEmail = $0["other_user_email"] as? String else { return false }
                return safeSenderEmail == targetSenderEmail })
            {
                guard let id = existingConversation["id"] as? String else { return completion(.failure(DatabaseError.failed)) }
                return completion(.success(id))
            }
            return completion(.failure(DatabaseError.failed))
        })
    }
}
