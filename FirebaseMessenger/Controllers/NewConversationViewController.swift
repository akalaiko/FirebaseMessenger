//
//  NewConversationViewController.swift
//  FirebaseMessenger
//
//  Created by Tim on 28.12.2022.
//

import UIKit
import JGProgressHUD

class NewConversationViewController: UIViewController {
    
    public var completion: (([String: String]) ->(Void))?
    private let spinner = JGProgressHUD(style: .dark)
    
    private var users = [[String: String]]()
    private var hasFetched = false
    private var results = [[String: String]]()
    
    private let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search..."
        return searchBar
    }()
    
    private let tableview: UITableView = {
        let table = UITableView()
        table.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
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
        view.backgroundColor = .white
        view.addSubview(tableview)
        view.addSubview(noResultsLabel)
        
        searchBar.delegate = self
        tableview.delegate = self
        tableview.dataSource = self
        
        navigationController?.navigationBar.topItem?.titleView = searchBar
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cancel", style: .done, target: self, action: #selector(dismissSelf))
        
        searchBar.becomeFirstResponder()
      
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableview.frame = view.bounds
        noResultsLabel.frame = CGRect(x: view.width/4, y: (view.height-200)/2, width: view.width/2, height: 200)
    }
    
    @objc func dismissSelf() {
        self.dismiss(animated: true)
    }
    
}

extension NewConversationViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let text = searchBar.text, !text.replacingOccurrences(of: " ", with: "").isEmpty else { return }
        
        searchBar.resignFirstResponder()
        
        results.removeAll()
        spinner.show(in: view)
        searchUsers(query: text)
        
    }
    
    func searchUsers(query: String) {
        if hasFetched {
            filterUsers(with: query)
        } else {
            DatabaseManager.shared.getAllUsers(completion: { [weak self] result in
                switch result {
                case .success(let users):
                    self?.hasFetched = true
                    self?.users = users
                    self?.filterUsers(with: query)
                case .failure(let error):
                    print(error)
                }
            })
        }
    }
    
    func filterUsers(with term: String) {
        guard hasFetched else { return }
        
        spinner.dismiss(animated: true)
        let results: [[String: String]] = users.filter({
            guard let name = $0["name"]?.lowercased() else { return false }
            return name.hasPrefix(term.lowercased())
        })
        
        self.results = results
        updateUI()
    }
    
    func updateUI() {
        if results.isEmpty {
            noResultsLabel.isHidden = false
            tableview.isHidden = true
        } else {
            noResultsLabel.isHidden = true
            tableview.isHidden = false
            tableview.reloadData()
        }
    }
}

extension NewConversationViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        results.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = results[indexPath.row]["name"]
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let targetUser = results[indexPath.row]
        
        dismiss(animated: true) { [weak self] in
            self?.completion?(targetUser)
        }
    }
    
}
