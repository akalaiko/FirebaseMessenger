//
//  LoginViewController.swift
//  FirebaseMessenger
//
//  Created by Tim on 28.12.2022.
//

import UIKit
import FirebaseAuth
import FacebookLogin
import JGProgressHUD

class LoginViewController: UIViewController {
    
    private let spinner = JGProgressHUD(style: .dark)
    
    private var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.clipsToBounds = true
        return scrollView
    }()
    
    private var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "logo")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private var emailField: UITextField = {
        let field = UITextField()
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.returnKeyType = .continue
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Email Address..."
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .white
        return field
    }()
    
    private var passwordField: UITextField = {
        let field = UITextField()
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.returnKeyType = .done
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Password..."
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .white
        field.isSecureTextEntry = true
        return field
    }()
    
    private var loginButton: UIButton = {
        let button = UIButton()
        button.setTitle("Login", for: .normal)
        button.backgroundColor = .link
        button.tintColor = .white
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        return button
    }()
    
    private var facebookLoginButton: FBLoginButton = {
        let button = FBLoginButton()
        button.permissions = ["public_profile", "email"]
        button.backgroundColor = .link
        button.tintColor = .white
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        title = "Log In"
        navigationItem.largeTitleDisplayMode = .never
        tabBarController?.tabBar.isHidden = true
        
        emailField.delegate = self
        passwordField.delegate = self
        facebookLoginButton.delegate = self
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Register", style: .plain, target: self, action: #selector(registerTapped))
        navigationItem.hidesBackButton = true
        
        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)
        
        // add subviews
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        scrollView.addSubview(emailField)
        scrollView.addSubview(passwordField)
        scrollView.addSubview(loginButton)
        scrollView.addSubview(facebookLoginButton)
        
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds
        let size = scrollView.width / 3
        imageView.frame = CGRect(x: size, y: 120, width: size, height: size)
        emailField.frame = CGRect(x: 40, y: imageView.bottom + 40, width: scrollView.width - 80, height: 52)
        passwordField.frame = CGRect(x: 40, y: emailField.bottom + 10, width: scrollView.width - 80, height: 52)
        loginButton.frame = CGRect(x: 40, y: passwordField.bottom + 40, width: scrollView.width - 80, height: 52)
        facebookLoginButton.frame = CGRect(x: 40, y: loginButton.bottom + 10, width: scrollView.width - 80, height: 52)
    }
    
    @objc private func registerTapped() {
        let vc = RegisterViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func loginTapped() {
        
        emailField.resignFirstResponder()
        passwordField.resignFirstResponder()
        
        guard let email = emailField.text,
              let password = passwordField.text,
              !email.isEmpty, !password.isEmpty, password.count >= 6
        else {
            alertLoginError()
            return
        }
        
        spinner.show(in: view, animated: true)
        
        // firebase login
        FirebaseAuth.Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
//            guard let self else { return }
            
            DispatchQueue.main.async {
                self?.spinner.dismiss(animated: true)
            }
            
            guard let result = authResult, error == nil else {
                print("failed to login in user with email: \(email)")
                return
            }
            let user = result.user
            let safeEmail = DatabaseManager.safeEmail(email: email)
            
            DatabaseManager.shared.getDataFor(path: safeEmail, completion: { result in
                switch result {
                case .success(let data):
                    guard let userData = data as? [String: Any],
                          let firstName = userData["first_name"] as? String,
                          let lastName = userData["last_name"] as? String
                    else {
                        return
                    }
                    UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "name")
                    
                case .failure(let error):
                    print("failed to read data with error:", error)
                }
            })
            
            UserDefaults.standard.set(email, forKey: "email")
            print("great success", user)
            NotificationCenter.default.post(Notification(name: .didLogInNotification))
            self?.navigationController?.popToRootViewController(animated: true)
        }
    }
    
    private func alertLoginError(message: String = "Please enter all info to log in.") {
        let alert = UIAlertController(title: "Ooops!",
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }
}

extension LoginViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == emailField {
            passwordField.becomeFirstResponder()
        } else if textField == passwordField {
            loginTapped()
        }
        return true
    }
}

extension LoginViewController: LoginButtonDelegate {
    func loginButtonDidLogOut(_ loginButton: FBLoginButton) {
        // no operation
    }
    
    func loginButton(_ loginButton: FBLoginButton, didCompleteWith result: LoginManagerLoginResult?, error: Error?) {
        guard let token = result?.token?.tokenString else {
            print("failed to log in with facebook")
            return
        }
        
        let facebookRequest = FBSDKLoginKit.GraphRequest(graphPath: "me",
                                                         parameters: ["fields": "email, first_name, last_name, picture.type(large)"],
                                                         tokenString: token, version: nil,
                                                         httpMethod: .get)
        
        facebookRequest.start() { _, result, error in
            guard let result = result as? [String: Any], error == nil else {
                print("facebook request failed")
                return
            }
            guard let firstName = result["first_name"] as? String,
                  let lastName = result["last_name"] as? String,
                  let email = result["email"] as? String,
                  let picture = result["picture"] as? [String: Any],
                  let data = picture["data"] as? [String: Any],
                  let pictureURL = data["url"] as? String
            else {
                print("failed to get data from facebook request")
                return
            }
            
            UserDefaults.standard.set(email, forKey: "email")
            UserDefaults.standard.set("\(firstName) \(lastName)", forKey: "name")
            
            
            DatabaseManager.shared.userExists(with: email, completion: { exists in
                guard !exists else { return }
                print("user exists, but we are still here ")
                let chatUser = ChatAppUser(firstName: firstName,
                                           lastName: lastName,
                                           emailAddress: email)
                UserDefaults.standard.set(chatUser.fullName, forKey: "name")
                
                DatabaseManager.shared.insertUser(with: chatUser, completion: { success in
                    if success {
                        guard let url = URL(string: pictureURL) else { return }
                        
                        print("downloading data from facebook image")
                        
                        URLSession.shared.dataTask(with: url, completionHandler: { data, _, _ in
                            guard let data else {
                                print("failed to get data from facebook")
                                return
                            }
                            
                            print("got data from fb, uploading...")
                            
                            let fileName = chatUser.profilePictureFileName
                            StorageManager.shared.uploadProfilePicture(with: data,fileName: fileName, completion: { result in
                                switch result {
                                case .success(let downloadURL):
                                    UserDefaults.standard.set(downloadURL, forKey: "profile_picture_url")
                                    print(downloadURL)
                                case .failure(let error):
                                    print(error)
                                }
                            })
                        }).resume()
                    }
                })
            })
            
            let credential = FacebookAuthProvider.credential(withAccessToken: token)
            
            FirebaseAuth.Auth.auth().signIn(with: credential) { [weak self] authResult, error in
                guard let self, let result = authResult, error == nil else { return }
                
                let user = result.user
                
                print("great success", user)
                NotificationCenter.default.post(Notification(name: .didLogInNotification))
                self.navigationController?.popToRootViewController(animated: true)
            }
        }
    }
}

