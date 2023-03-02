//
//  NewConversationCell.swift
//  FirebaseMessenger
//
//  Created by Tim on 02.02.2023.
//

import Foundation
import SDWebImage

final class NewConversationCell: UITableViewCell {
    
    static let identifier = "NewConversationCell"
    
    public let userImageView: UIImageView = {
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
        userNameLabel.text = model.name
    }
    
}
