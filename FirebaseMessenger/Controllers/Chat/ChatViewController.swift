//
//  ChatViewController.swift
//  FirebaseMessenger
//
//  Created by Tim on 24.01.2023.
//

import AVFoundation
import AVKit
import CoreLocation
import FirebaseStorage
import InputBarAccessoryView
import MessageKit
import SDWebImage
import UIKit

final class ChatViewController: MessagesViewController {
    
    public var isNewConversation = false
    public let otherUserEmail: String
    
    private var currentUserPhoto: UIImage?
    private var otherUserPhoto: UIImage?
    private var conversationId: String?
    private lazy var messages = [Message]()
    private lazy var currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String
    private lazy var currentUserName = UserDefaults.standard.value(forKey: "name") as? String
    private var selfSender: Sender? {
        guard let currentUserEmail, let currentUserName else { return nil }
        let safeEmail = DatabaseManager.safeEmail(email: currentUserEmail)
        let sender = Sender(senderId: safeEmail,
                            displayName: currentUserName)
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
        button.onTouchUpInside { [weak self] _ in self?.presentInputActionSheet() }
        messageInputBar.setLeftStackViewWidthConstant(to: 36, animated: false)
        messageInputBar.setStackViewItems([button], forStack: .left, animated: false)
    }
    
    private func presentInputActionSheet() {
        let actionSheet = UIAlertController(title: "Attach media", message: "What would you like to attach?", preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Photo", style: .default){ [weak self] _ in self?.presentPhotoInputActionSheet() })
        actionSheet.addAction(UIAlertAction(title: "Video", style: .default){ [weak self] _ in self?.presentVideoInputActionSheet() })
        actionSheet.addAction(UIAlertAction(title: "Location", style: .default){ [weak self] _ in self?.presentLocationPicker() })
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(actionSheet, animated: true)
    }
    
    private func presentPhotoInputActionSheet() {
        let actionSheet = UIAlertController(title: "Attach photo", message: "Where would you like to attach a photo from?", preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default){ [weak self] _ in self?.presentPicker(sourceType: .camera) })
        actionSheet.addAction(UIAlertAction(title: "Photo library", style: .default){ [weak self] _ in self?.presentPicker(sourceType: .photoLibrary) })
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(actionSheet, animated: true)
    }
    
    private func presentVideoInputActionSheet() {
        let actionSheet = UIAlertController(title: "Attach video", message: "Where would you like to attach a video from?", preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default){ [weak self] _ in self?.presentPicker(sourceType: .camera, videoQuality: .typeMedium) })
        actionSheet.addAction(UIAlertAction(title: "Library", style: .default){ [weak self] _ in self?.presentPicker(sourceType: .photoLibrary, videoQuality: .typeMedium) })
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(actionSheet, animated: true)
    }
    
    private func presentPicker(sourceType: UIImagePickerController.SourceType, videoQuality: UIImagePickerController.QualityType? = nil) {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = self
        picker.allowsEditing = true
        if let videoQuality {
            picker.mediaTypes = ["public.movie"]
            picker.videoQuality = videoQuality
        }
        present(picker, animated: true)
    }
    
    private func presentLocationPicker() {
        let vc = LocationPickerViewController()
        vc.navigationItem.largeTitleDisplayMode = .never
        vc.completion = { [weak self] selectedCoordinates in
            let longtitude: Double = selectedCoordinates.longitude
            let latitude: Double = selectedCoordinates.latitude
            
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
            DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: otherUserEmail, name: name, message: message) { _ in }
        }
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .popover
        present(nav, animated: true)
    }
    
    private func createMessageId() -> String? {
        guard let currentUserEmail else { return nil }
        let safeEmail = DatabaseManager.safeEmail(email: currentUserEmail)
        let dateString = DatabaseManager.dateFormatter.string(from: Date())
        let newId = otherUserEmail + safeEmail + dateString
        return newId
    }
    
    private func listenForMessages(id: String, shouldScrollToBottom: Bool) {
        DatabaseManager.shared.getAllMessagesForConversation(with: id, completion: { [weak self] result in
            switch result {
            case .success(let messages):
                guard !messages.isEmpty else { return }
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
        let message = Message(sender: selfSender, messageId: messageId, sentDate: Date(), kind: .text(text))
        
        if isNewConversation {
            DatabaseManager.shared.createNewConversation(with: otherUserEmail, name: title ?? "User", firstMessage: message, completion: { [weak self] success in
                if success {
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
        if message.sender.senderId == selfSender?.senderId { return .link }
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
    
    private func setAvatar(for email: String?, to view: UIImageView, completion: @escaping () -> Void) {
        guard let email else { return }
        let path = DatabaseManager.getProfilePicturePath(email: email)
        StorageManager.shared.downloadURL(for: path, completion: { result in
            switch result {
            case.success(let urlString):
                guard let url = URL(string: urlString) else { return }
                view.sd_setImage(with: url)
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
        var filename = ""
        var mediaData = Data()
        var isVideo = false
        
        if let image = info[.editedImage] as? UIImage, let imageData = image.pngData() {
            filename = "photo_message_" + messageId.replacingOccurrences(of: " ", with: "-") + ".png"
            mediaData = imageData
            isVideo = false
        } else if let videoUrl = info[.mediaURL] as? URL, let videoData = NSData(contentsOf: videoUrl) as Data? {
            filename = "video_message_" + messageId.replacingOccurrences(of: " ", with: "-") + ".mov"
            mediaData = videoData
            isVideo = true
        }
        
        StorageManager.shared.uploadMessageMedia(with: mediaData, fileName: filename, completion: { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let urlString):
                let url = URL(string: urlString)
                let media = Media(url: url, placeholderImage: placeholder, size: .zero)
                if isVideo {
                    let message = Message(sender: selfSender, messageId: messageId, sentDate: Date(), kind: .video(media))
                    DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: self.otherUserEmail, name: name, message: message) { _ in }
                } else {
                    let message = Message(sender: selfSender, messageId: messageId, sentDate: Date(), kind: .photo(media))
                    DatabaseManager.shared.sendMessage(to: conversationId, otherUserEmail: self.otherUserEmail, name: name, message: message) { _ in }
                }
            case .failure(let error):
                print(error)
            }
        })
    }
}
