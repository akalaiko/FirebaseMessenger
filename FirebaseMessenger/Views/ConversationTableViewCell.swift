//
//  ConversationTableViewCell.swift
//  FirebaseMessenger
//
//  Created by Tim on 31.01.2023.
//

import UIKit
import SDWebImage

class ConversationTableViewCell: UITableViewCell {
    
    static let identifier = "ConversationTableViewCell"
    
    private let userImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 35
        imageView.layer.masksToBounds = true
        return imageView
    }()
    
    private let userNameLabel: UILabel = {
        var label = UILabel()
        label.font = .systemFont(ofSize: 21, weight: .semibold)
        return label
    }()
    
    private let userMessageLabel: UILabel = {
        var label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .regular)
        label.numberOfLines = 0
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(userImageView)
        contentView.addSubview(userNameLabel)
        contentView.addSubview(userMessageLabel)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        userImageView.frame = CGRect(x: 15, y: 15, width: 70, height: 70)
        userNameLabel.frame = CGRect(x: userImageView.right + 15,
                                     y: 15,
                                     width: contentView.width - 30 - userImageView.width,
                                     height: contentView.height/2 - 15)
        userMessageLabel.frame = CGRect(x: userImageView.right + 15,
                                        y: userNameLabel.bottom,
                                        width: contentView.width - 30 - userImageView.width,
                                        height: contentView.height/2 - 15)
    }
    
    public func configure(with model: Conversation) {
        userMessageLabel.text = model.latestMessage.text
        userNameLabel.text = model.name
        
        let path = DatabaseManager.getProfilePicturePath(email: model.otherUserEmail)
        StorageManager.shared.downloadURL(for: path, completion: { [weak self] result in
            switch result {
            case .success(let urlString):
                let url = URL(string: urlString)
                DispatchQueue.main.async {
                    self?.userImageView.sd_setImage(with: url)
                }
            case .failure(let error):
                print(error)
            }
        })
    }
    
}
