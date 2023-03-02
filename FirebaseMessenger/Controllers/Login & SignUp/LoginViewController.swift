//
//  LoginViewController.swift
//  FirebaseMessenger
//
//  Created by Tim on 28.12.2022.
//

import FacebookLogin
import FirebaseAuth
import UIKit

final class LoginViewController: UIViewController {

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
        field.backgroundColor = .secondarySystemBackground
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
        field.backgroundColor = .secondarySystemBackground
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
    
    private var registrationButton: UIButton = {
        let button = UIButton()
        button.setTitle("Sign Up", for: .normal)
        button.setTitleColor(.link, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        emailField.delegate = self
        passwordField.delegate = self
        facebookLoginButton.delegate = self
        
        navigationController?.navigationBar.isHidden = true
        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)
        registrationButton.addTarget(self, action: #selector(registerTapped), for: .touchUpInside)
        
        // add subviews
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        scrollView.addSubview(emailField)
        scrollView.addSubview(passwordField)
        scrollView.addSubview(loginButton)
        scrollView.addSubview(facebookLoginButton)
        scrollView.addSubview(registrationButton)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds
        
        let imageSize = scrollView.width / 3
        let width = scrollView.width - 80
        let height: CGFloat = 52
        let smallPadding: CGFloat = 10
        let largePadding: CGFloat = 40
        
        imageView.frame = CGRect(x: imageSize, y: largePadding * 2, width: imageSize, height: imageSize)
        emailField.frame = CGRect(x: largePadding, y: imageView.bottom + largePadding, width: width, height: height)
        passwordField.frame = CGRect(x: largePadding, y: emailField.bottom + smallPadding, width: width, height: height)
        loginButton.frame = CGRect(x: largePadding, y: passwordField.bottom + largePadding, width: width, height: height)
        facebookLoginButton.frame = CGRect(x: largePadding, y: loginButton.bottom + smallPadding, width: width, height: height)
        registrationButton.frame = CGRect(x: largePadding, y: facebookLoginButton.bottom + smallPadding, width: width, height: height)
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

        // firebase login
        FirebaseAuth.Auth.auth().signIn(withEmail: email, password: password) { [weak self] _, error in
            
            guard error == nil else { return print("failed to login in user with email: \(email)") }
            let safeEmail = DatabaseManager.safeEmail(email: email)
            
            DatabaseManager.shared.getDataFor(path: "users/\(safeEmail)", completion: { result in
                switch result {
                case .success(let data):
                    guard let userData = data as? [String: Any],
                          let name = userData["name"] as? String
                    else {
                        return
                    }
                    UserDefaults.standard.set(name, forKey: "name")
                    UserDefaults.standard.set(email, forKey: "email")
                    NotificationCenter.default.post(Notification(name: .didLogInNotification))
                    self?.navigationController?.popToRootViewController(animated: true)
                case .failure(let error):
                    print("failed to read data with error:", error)
                }
            })
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
        // needed by protocol, but unused
    }
    
    func loginButton(_ loginButton: FBLoginButton, didCompleteWith result: LoginManagerLoginResult?, error: Error?) {
        guard let token = result?.token?.tokenString else { return print("failed to log in with facebook") }
        
        let facebookRequest = FBSDKLoginKit.GraphRequest(graphPath: "me",
                                                         parameters: ["fields": "email, first_name, last_name, picture.type(large)"],
                                                         tokenString: token, version: nil,
                                                         httpMethod: .get)
        facebookRequest.start() { _, result, _ in
            guard let result = result as? [String: Any], error == nil else { return print("facebook request failed") }
            guard let firstName = result["first_name"] as? String,
                  let lastName = result["last_name"] as? String,
                  let email = result["email"] as? String,
                  let picture = result["picture"] as? [String: Any],
                  let data = picture["data"] as? [String: Any],
                  let pictureURL = data["url"] as? String
            else {
                return print("failed to get data from facebook request")
            }
            
            DatabaseManager.shared.userExists(with: email, completion: { exists in
                guard !exists else { return }
                let chatUser = User(firstName: firstName,
                                           lastName: lastName,
                                           emailAddress: email)
                UserDefaults.standard.set(chatUser.fullName, forKey: "name")
                UserDefaults.standard.set(email, forKey: "email")
                
                DatabaseManager.shared.insertUser(with: chatUser, completion: { success in
                    if success {
                        guard let url = URL(string: pictureURL) else { return }
                        URLSession.shared.dataTask(with: url, completionHandler: { data, _, _ in
                            guard let data else { return print("failed to get data from facebook") }
                            let fileName = chatUser.profilePictureFileName
                            StorageManager.shared.uploadProfilePicture(with: data,fileName: fileName, completion: { _ in
                                UserDefaults.standard.set(data, forKey: "profile_picture")
                            })
                        }).resume()
                    }
                })
            })
            
            let credential = FacebookAuthProvider.credential(withAccessToken: token)
            FirebaseAuth.Auth.auth().signIn(with: credential) { [weak self] _, error in
                guard error == nil else { return }
                NotificationCenter.default.post(Notification(name: .didLogInNotification))
                self?.navigationController?.popToRootViewController(animated: true)
            }
        }
    }
}

