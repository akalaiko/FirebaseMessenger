//
//  NewConversationViewController.swift
//  FirebaseMessenger
//
//  Created by Tim on 28.12.2022.
//

import SDWebImage
import UIKit

final class NewConversationViewController: UIViewController {
    
    public var completion: ((SearchResult) ->(Void))?
    
    private let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String
    private var users = [[String: Any]]()
    private var hasFetched = false
    private var results = [SearchResult]()
    
    private let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search..."
        return searchBar
    }()
    
    private let tableview: UITableView = {
        let table = UITableView()
        table.register(NewConversationCell.self, forCellReuseIdentifier: NewConversationCell.identifier)
        table.isHidden = true
        return table
    }()
    
    private let noResultsLabel: UILabel = {
        let label = UILabel()
        label.text = "No results found"
        label.textAlignment = .center
        label.textColor = .gray
        label.font = .systemFont(ofSize: 21, weight: .medium)
        label.isHidden = true
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.addSubview(tableview)
        view.addSubview(noResultsLabel)
        
        searchBar.delegate = self
        searchBar.becomeFirstResponder()
        
        tableview.delegate = self
        tableview.dataSource = self
        
        navigationController?.navigationBar.topItem?.titleView = searchBar
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cancel", style: .done, target: self, action: #selector(dismissSelf))
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableview.frame = view.bounds
        noResultsLabel.frame = CGRect(x: view.width/4, y: (view.height-200)/2, width: view.width/2, height: 200)
    }
    
    @objc private func dismissSelf() {
        dismiss(animated: true)
    }
    
}

extension NewConversationViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let text = searchBar.text, !text.replacingOccurrences(of: " ", with: "").isEmpty else { return }
        searchBar.resignFirstResponder()
        results.removeAll()
        searchUsers(query: text)
    }
    
    private func searchUsers(query: String) {
        if hasFetched {
            filterUsers(with: query)
        } else {
            DatabaseManager.shared.getAllUsers(completion: { [weak self] result in
                switch result {
                case .success(let users):
                    self?.hasFetched = true
                    self?.users = users.compactMap({ $0.value as? [String: Any] })
                    self?.filterUsers(with: query)
                case .failure(let error):
                    print(error)
                }
            })
        }
    }
    
    private func filterUsers(with term: String) {
        guard let currentUserEmail, hasFetched else { return }
        let safeEmail = DatabaseManager.safeEmail(email: currentUserEmail)
        let searchResults: [SearchResult] = users.filter({
            guard let email = $0["email"] as? String, email != safeEmail,
                  let name = $0["name"] as? String else { return false }
            return name.lowercased().contains(term.lowercased())
        }).compactMap ({
            guard let name = $0["name"] as? String,
                  let email = $0["email"] as? String else { return nil }
            return SearchResult(name: name, email: email)
        })
        results = searchResults
        updateUI()
    }
    
    private func updateUI() {
        noResultsLabel.isHidden = !results.isEmpty
        tableview.isHidden = results.isEmpty
        tableview.reloadData()
    }
}

extension NewConversationViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        results.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: NewConversationCell.identifier, for: indexPath) as? NewConversationCell else { return UITableViewCell() }
        let model = results[indexPath.row]
        cell.configure(with: model)
        
        let path = DatabaseManager.getProfilePicturePath(email: model.email)
        StorageManager.shared.downloadURL(for: path, completion: { result in
            switch result {
            case .success(let urlString):
                let url = URL(string: urlString)
                DispatchQueue.main.async {
                    cell.userImageView.sd_setImage(with: url)
                }
            case .failure(let error):
                print(error)
            }
        })
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let targetUser = results[indexPath.row]
        
        dismiss(animated: true) { [weak self] in
            self?.completion?(targetUser)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        70
    }
}
