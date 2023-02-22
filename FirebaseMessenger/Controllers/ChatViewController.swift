//
//  ChatViewController.swift
//  FirebaseMessenger
//
//  Created by Tim on 24.01.2023.
//

import UIKit
import MessageKit
import InputBarAccessoryView
import SDWebImage
import AVFoundation
import AVKit
import CoreLocation

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

struct Sender: SenderType {
    var senderId: String
    var displayName: String
    var photoURL: String
}

struct Media: MediaItem {
    var url: URL?
    var image: UIImage?
    var placeholderImage: UIImage
    var size: CGSize
}

struct Location: LocationItem {
    var location: CLLocation
    var size: CGSize
}

class ChatViewController: MessagesViewController {
    
    public static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .long
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()
    
    private var currentUserPhoto: UIImage?
    private var otherUserPhoto: UIImage?
    
    
    public var isNewConversation = false
    public let otherUserEmail: String
    private var conversationId: String?
    
    private var messages = [Message]()
    
    private let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String
    
    private var selfSender: Sender? {
        guard let currentUserEmail else { return nil }
        let safeEmail = DatabaseManager.safeEmail(email: currentUserEmail)
        let sender = Sender(senderId: safeEmail,
                            displayName: "Me",
                            photoURL: "")
        return sender
    }
    
    init(with email: String, id: String?) {
        otherUserEmail = email
        conversationId = id
        super.init(nibName: nil, bundle: nil)
        
        if let conversationId {
            listenForMessages(id: conversationId, shouldScrollToBottom: true)
        }
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tabBarController?.tabBar.isHidden = true
        
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesLayoutDelegate = self
        messagesCollectionView.messagesDisplayDelegate = self
        messagesCollectionView.messageCellDelegate = self
        messageInputBar.delegate = self
        setupInputButton()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        messageInputBar.inputTextView.becomeFirstResponder()
    }
    
    
    private func setupInputButton() {
        let button = InputBarButtonItem()
        button.setSize(CGSize(width: 35, height: 35), animated: false)
        button.setImage(UIImage(systemName: "paperclip"), for: .normal)
        button.onTouchUpInside { [weak self] _ in
            self?.presentInputActionSheet()
        }
        messageInputBar.setLeftStackViewWidthConstant(to: 36, animated: false)
        messageInputBar.setStackViewItems([button], forStack: .left, animated: false)
    }
    
    private func presentInputActionSheet() {
        let actionSheet = UIAlertController(title: "Attech media", message: "What would you like to attach?", preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Photo", style: .default){ [weak self] _ in
            self?.presentPhotoInputActionSheet()
        })
        actionSheet.addAction(UIAlertAction(title: "Video", style: .default){ [weak self] _ in
            self?.presentVideoInputActionSheet()
        })
        actionSheet.addAction(UIAlertAction(title: "Audio", style: .default){ [weak self] _ in
            
        })
        actionSheet.addAction(UIAlertAction(title: "Location", style: .default){ [weak self] _ in
            self?.presentLocationPicker()
        })
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(actionSheet, animated: true)
    }
    
    private func presentPhotoInputActionSheet() {
        let actionSheet = UIAlertController(title: "Attach photo", message: "Where would you like to attach a photo from?", preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default){ [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        })
        actionSheet.addAction(UIAlertAction(title: "Photo library", style: .default){ [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        })
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(actionSheet, animated: true)
    }
    
    private func presentVideoInputActionSheet() {
        let actionSheet = UIAlertController(title: "Attach video", message: "Where would you like to attach a video from?", preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default){ [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        })
        actionSheet.addAction(UIAlertAction(title: "Library", style: .default){ [weak self] _ in
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = .typeMedium
            picker.delegate = self
            picker.allowsEditing = true
            self?.present(picker, animated: true)
        })
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(actionSheet, animated: true)
    }
    
    private func presentLocationPicker() {
        let vc = LocationPickerViewController()
        vc.navigationItem.largeTitleDisplayMode = .never
        vc.completion = { [weak self] selectedCoordinates in
            let longtitude: Double = selectedCoordinates.longitude
            let latitude: Double = selectedCoordinates.latitude
            
            print(longtitude, latitude)
            
            guard let messageId = self?.createMessageId(),
                  let conversationId = self?.conversationId,
                  let name = self?.title,
                  let otherUserEmail = self?.otherUserEmail,
                  let selfSender = self?.selfSender
            else {
                return
            }
            let locationItem = Location(location: CLLocation(latitude: latitude, longitude: longtitude), size: .zero)
            let message = Message(sender: selfSender, messageId: messageId, sentDate: Date(), kind: .location(locationItem))
            
            DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: otherUserEmail, name: name, message: message) { success in
                if success {
                    print("sent")
                } else {
                    print("failed to send a message in existing convo")
                }
            }
        }
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .popover
        present(nav, animated: true)
    }
    
    private func createMessageId() -> String? {
        // date, otherUserEmail, senderEmail
        guard let currentUserEmail else { return nil }
        let safeEmail = DatabaseManager.safeEmail(email: currentUserEmail)
        
        let dateString = Self.dateFormatter.string(from: Date())
        let newId = otherUserEmail + safeEmail + dateString
        
        return newId
    }
    
    private func listenForMessages(id: String, shouldScrollToBottom: Bool) {
        DatabaseManager.shared.getAllMessagesForConversation(with: id, completion: { [weak self] result in
            switch result {
            case .success(let messages):
                guard !messages.isEmpty else {
                    return }
                self?.messages = messages
                DispatchQueue.main.async {
                    self?.messagesCollectionView.reloadDataAndKeepOffset()
                    if shouldScrollToBottom {
                        self?.messagesCollectionView.scrollToLastItem()
                    }
                }
            case .failure(let error):
                print(error)
            }
        })
    }
}

extension ChatViewController: InputBarAccessoryViewDelegate {
    func inputBar(_ inputBar: InputBarAccessoryView, didPressSendButtonWith text: String) {
        guard !text.replacingOccurrences(of: " ", with: "").isEmpty,
              let selfSender,
              let messageId = createMessageId() else { return }
        print("are we even here?")
        let message = Message(sender: selfSender, messageId: messageId, sentDate: Date(), kind: .text(text))
        
        if isNewConversation {
            DatabaseManager.shared.createNewConversation(with: otherUserEmail, name: title ?? "User", firstMessage: message, completion: { [weak self] success in
                if success {
                    print("sent")
                    self?.isNewConversation = false
                    let newConversationId = "conversation_\(message.messageId)"
                    self?.conversationId = newConversationId
                    self?.listenForMessages(id: newConversationId, shouldScrollToBottom: true)
                    self?.messageInputBar.inputTextView.text = nil
                } else {
                    print("failed to send a message")
                }
            })
        } else {
            guard let conversationId else { return }
            DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: otherUserEmail, name: title ?? "User", message: message, completion: { [weak self] success in
                if success {
                    print("sent")
                    self?.messageInputBar.inputTextView.text = nil
                } else {
                    print("failed to send a message in existing convo")
                }
            })
        }
    }
}

extension ChatViewController: MessagesDataSource, MessagesLayoutDelegate, MessagesDisplayDelegate, MessageCellDelegate {
    var currentSender: MessageKit.SenderType {
        guard let selfSender else { fatalError("self sender is nil") }
        return selfSender
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessageKit.MessagesCollectionView) -> MessageKit.MessageType {
        messages[indexPath.section]
    }
    
    func numberOfSections(in messagesCollectionView: MessageKit.MessagesCollectionView) -> Int {
        messages.count
    }
    
    func configureMediaMessageImageView(_ imageView: UIImageView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        guard let message = message as? Message else { return }
        switch message.kind {
        case .photo(let media):
            guard let imageUrl = media.url else { return }
            imageView.sd_setImage(with: imageUrl)
        default: break
        }
    }
    
    func didTapImage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else { return }
        let message = messages[indexPath.section]
        switch message.kind {
        case .photo(let media):
            guard let imageUrl = media.url else { return }
            
            let vc = PhotoViewerViewController(with: imageUrl)
            navigationController?.pushViewController(vc, animated: true)
        case .video(let media):
            guard let videoUrl = media.url else { return }
            
            let vc = AVPlayerViewController()
            vc.player = AVPlayer(url: videoUrl)
            vc.player?.play()
            present(vc, animated: true)
        default: break
        }
    }
    
    func didTapMessage(in cell: MessageCollectionViewCell) {
        guard let indexPath = messagesCollectionView.indexPath(for: cell) else { return }
        let message = messages[indexPath.section]
        switch message.kind {
        case .location(let locationData):
            let coordinates = locationData.location.coordinate
            let vc = LocationPickerViewController(coordinates: coordinates)
            
            let nav = UINavigationController(rootViewController: vc)
            nav.modalPresentationStyle = .popover
            present(nav, animated: true)
        default: break
        }
    }
    
    func backgroundColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        let sender = message.sender
        if sender.senderId == selfSender?.senderId {
            return .link
        }
        return .secondarySystemBackground
    }
    
    func configureAvatarView(_ avatarView: AvatarView, for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) {
        let sender = message.sender
        
        if sender.senderId == selfSender?.senderId {
            if let currentUserPhoto {
                avatarView.image = currentUserPhoto
            } else {
                setAvatar(for: currentUserEmail, to: avatarView) { [weak self] in self?.currentUserPhoto = avatarView.image }
            }
        } else {
            if let otherUserPhoto {
                avatarView.image = otherUserPhoto
            } else {
                setAvatar(for: otherUserEmail, to: avatarView) { [weak self] in self?.otherUserPhoto = avatarView.image }
            }
        }
    }

    func setAvatar(for email: String?, to view: UIImageView, completion: @escaping () -> Void) {
        guard let email else { return }
        let path = DatabaseManager.getProfilePicturePath(email: email)
        StorageManager.shared.downloadURL(for: path, completion: { result in
            switch result {
            case.success(let urlString):
                guard let url = URL(string: urlString) else { return }
                URLSession.shared.dataTask(with: url, completionHandler: { data, _, error in
                    guard let data, error == nil else { return }
                    let image = UIImage(data: data)
                    DispatchQueue.main.async {
                        view.image = image
                        completion()
                    }
                }).resume()
            case .failure(let error):
                print(error)
            }
        })
    }
}

extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        guard let messageId = createMessageId(),
              let conversationId,
              let name = title,
              let selfSender,
              let placeholder = UIImage(systemName: "photo")
        else {
            return
        }
        
        if let image = info[.editedImage] as? UIImage, let imageData = image.pngData() {
            
            let filename = "photo_message_" + messageId.replacingOccurrences(of: " ", with: "-") + ".png"
            
            StorageManager.shared.uploadMessagePhoto(with: imageData, fileName: filename, completion: { [weak self] result in
                guard let self else { return }
                
                switch result {
                case .success(let urlString):
                    print("uploaded message photo:", urlString)
                    let url = URL(string: urlString)
                    let media = Media(url: url, placeholderImage: placeholder, size: .zero)
                    let message = Message(sender: selfSender, messageId: messageId, sentDate: Date(), kind: .photo(media))
                    
                    DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: self.otherUserEmail, name: name, message: message) { success in
                        if success {
                            print("sent")
                        } else {
                            print("failed to send a message in existing convo")
                        }
                    }
                case .failure(let error):
                    print(error)
                }
            })
            
        } else if let videoUrl = info[.mediaURL] as? URL {
            let filename = "video_message_" + messageId.replacingOccurrences(of: " ", with: "-") + ".mov"
            
            StorageManager.shared.uploadMessageVideo(with: videoUrl, fileName: filename, completion: { [weak self] result in
                guard let self else { return }
                
                switch result {
                case .success(let urlString):
                    print("uploaded message video:", urlString)
                    let url = URL(string: urlString)
                    let media = Media(url: url, placeholderImage: placeholder, size: .zero)
                    let message = Message(sender: selfSender, messageId: messageId, sentDate: Date(), kind: .video(media))
                    
                    DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: self.otherUserEmail, name: name, message: message) { success in
                        if success {
                            print("sent")
                        } else {
                            print("failed to send a message in existing convo")
                        }
                    }
                case .failure(let error):
                    print(error)
                }
            })
            
        }
    }
}
