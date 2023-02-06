//
//  NewConversationCell.swift
//  FirebaseMessenger
//
//  Created by Tim on 02.02.2023.
//

import Foundation
import SDWebImage

class NewConversationCell: UITableViewCell {
    
    static let identifier = "NewConversationCell"
    
    private let userImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 25
        imageView.layer.masksToBounds = true
        return imageView
    }()
    
    private let userNameLabel: UILabel = {
        var label = UILabel()
        label.font = .systemFont(ofSize: 21, weight: .semibold)
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(userImageView)
        contentView.addSubview(userNameLabel)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        userImageView.frame = CGRect(x: 10, y: 10, width: 50, height: 50)
        userNameLabel.frame = CGRect(x: userImageView.right + 15,
                                     y: contentView.height/4,
                                     width: contentView.width - 30 - userImageView.width,
                                     height: contentView.height/2)
    }
    
    public func configure(with model: SearchResult) {
        self.userNameLabel.text = model.name
        
        let path = DatabaseManager.getProfilePicturePath(email: model.email)
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
