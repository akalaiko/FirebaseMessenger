//
//  ProfileViewViewController.swift
//  FirebaseMessenger
//
//  Created by Tim on 28.12.2022.
//

import UIKit
import FirebaseAuth
import FacebookLogin

class ProfileViewViewController: UIViewController {
    
    var tableView: UITableView!
    var data = ["name", "email", "Log out"]
    var cachedAvatar: UIImage?
    
    override func loadView() {
        tableView = UITableView()
        view = tableView
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        data[0] = UserDefaults.standard.value(forKey: "name") as? String ?? ""
        data[1] = UserDefaults.standard.value(forKey: "email") as? String ?? ""
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.tabBar.isHidden = false
        tableView.tableHeaderView = createTableHeader()
    }
    
    func createTableHeader() -> UIView? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else { return nil }
        let path = DatabaseManager.getProfilePicturePath(email: email)
        
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: view.width, height: 150))
        headerView.backgroundColor = .systemBackground
        
        let imageView = UIImageView(frame: CGRect(x: 136.5, y: 15, width: 120, height: 120))
        
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .white
        imageView.layer.borderColor = UIColor.white.cgColor
        imageView.layer.borderWidth = 3
        imageView.layer.cornerRadius = imageView.width / 2
        imageView.layer.masksToBounds = true
        headerView.addSubview(imageView)
        
        if let cachedAvatar {
            imageView.image = cachedAvatar
        } else {
            StorageManager.shared.downloadURL(for: path, completion: { [weak self] result in
                switch result {
                case .success(let url):
                    self?.downloadImage(imageView: imageView, urlString: url) { [weak self] in self?.cachedAvatar = imageView.image }
                case .failure(let error):
                    print("failed to get download url:", error)
                }
            })
        }
        
        
        return headerView
    }
    
    func downloadImage(imageView: UIImageView, urlString: String, completion: @escaping () -> Void) {
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url, completionHandler: { data, _, error in
            guard let data, error == nil else { return }
            
            DispatchQueue.main.async {
                let image = UIImage(data: data)
                imageView.image = image
                completion()
            }
        }).resume()
    }
    
}

extension ProfileViewViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        data.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.textAlignment = .center
        cell.selectionStyle = .none
        
        if indexPath.row == 0 {
            cell.textLabel?.text = data[indexPath.row].uppercased()
            cell.textLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        }
        
        if indexPath.row == 1 {
            cell.textLabel?.text = data[indexPath.row]
        }
        
        if indexPath.row == 2 {
            cell.textLabel?.text = data[indexPath.row].uppercased()
            cell.textLabel?.textColor = .red
            cell.selectionStyle = .default
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.row == data.count - 1 else { return }
        tableView.deselectRow(at: indexPath, animated: true)
        
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Log out", style: .destructive) { [weak self] _ in
            UserDefaults.standard.set(nil, forKey: "email")
            UserDefaults.standard.set(nil, forKey: "name")
            UserDefaults.standard.set(nil, forKey: "profile_picture_url")
            self?.cachedAvatar = nil
            
            FacebookLogin.LoginManager().logOut()
            
            do {
                try FirebaseAuth.Auth.auth().signOut()
                
                let vc = LoginViewController()
                self?.navigationController?.pushViewController(vc, animated: false)
            } catch {
                print ("failed")
            }
        })
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(actionSheet, animated: true)
        
    }
    
    
}
