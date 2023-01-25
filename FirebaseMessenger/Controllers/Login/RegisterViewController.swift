//
//  RegisterViewController.swift
//  FirebaseMessenger
//
//  Created by Tim on 28.12.2022.
//

import UIKit
import FirebaseAuth
import JGProgressHUD

class RegisterViewController: UIViewController {
    
    private let spinner = JGProgressHUD(style: .dark)
    
    private var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.clipsToBounds = true
        return scrollView
    }()
    
    private var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "person.circle")
        imageView.tintColor = .gray
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.layer.masksToBounds = true
        imageView.layer.borderColor = UIColor.lightGray.cgColor
        imageView.layer.borderWidth = 1
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
    
    private var firstNameField: UITextField = {
        let field = UITextField()
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.returnKeyType = .continue
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "First Name..."
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .white
        return field
    }()
    
    private var lastNameField: UITextField = {
        let field = UITextField()
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.returnKeyType = .continue
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor.lightGray.cgColor
        field.placeholder = "Last Name..."
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 0))
        field.leftViewMode = .always
        field.backgroundColor = .white
        return field
    }()
    
    private var registerButton: UIButton = {
        let button = UIButton()
        button.setTitle("Register", for: .normal)
        button.backgroundColor = .systemGreen
        button.tintColor = .white
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "Register"
        
        emailField.delegate = self
        passwordField.delegate = self
        
        registerButton.addTarget(self, action: #selector(registerButtonTapped), for: .touchUpInside)
        
        // add subviews
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        scrollView.addSubview(firstNameField)
        scrollView.addSubview(lastNameField)
        scrollView.addSubview(emailField)
        scrollView.addSubview(passwordField)
        scrollView.addSubview(registerButton)
        
        let gesture = UITapGestureRecognizer(target: self, action: #selector(didTapChangeProfilePic))
        imageView.addGestureRecognizer(gesture)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scrollView.frame = view.bounds
        let size = scrollView.width / 3
        imageView.frame = CGRect(x: size, y: 80, width: size, height: size)
        imageView.layer.cornerRadius = imageView.width / 2
        firstNameField.frame = CGRect(x: 40, y: imageView.bottom + 40, width: scrollView.width - 80, height: 52)
        lastNameField.frame = CGRect(x: 40, y: firstNameField.bottom + 10, width: scrollView.width - 80, height: 52)
        emailField.frame = CGRect(x: 40, y: lastNameField.bottom + 10, width: scrollView.width - 80, height: 52)
        passwordField.frame = CGRect(x: 40, y: emailField.bottom + 10, width: scrollView.width - 80, height: 52)
        registerButton.frame = CGRect(x: 40, y: passwordField.bottom + 40, width: scrollView.width - 80, height: 52)
    }
    
    @objc func didTapChangeProfilePic() {
        presentPhotoActionSheet()
    }
    
    @objc private func registerButtonTapped() {
        
        firstNameField.resignFirstResponder()
        lastNameField.resignFirstResponder()
        emailField.resignFirstResponder()
        passwordField.resignFirstResponder()
        
        guard let firstName = firstNameField.text,
              let lastName = lastNameField.text,
              let email = emailField.text,
              let password = passwordField.text,
              !email.isEmpty, !password.isEmpty, !firstName.isEmpty, !lastName.isEmpty, password.count >= 6
        else {
            alertLoginError(with: "Please enter all info to create a new account.")
            return
        }
        
        spinner.show(in: view, animated: true)
        
        // firebase register
        
        DatabaseManager.shared.userExists(with: email, completion: { [weak self] exists in
            guard let self else { return }
            
            DispatchQueue.main.async {
                self.spinner.dismiss(animated: true)
            }
            
            guard !exists else {
                self.alertLoginError(with: "User already exists!")
                return
            }
            print("somehow we are here")
            
            FirebaseAuth.Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
                guard authResult != nil, error == nil else {
                    print("error creating new user")
                    return
                }
                let chatUser = ChatAppUser(firstName: firstName,
                                           lastName: lastName,
                                           emailAddress: email)
                DatabaseManager.shared.insertUser(with: chatUser, completion: { success in
                    if success {
                        guard let image = self.imageView.image,
                              let data = image.pngData()
                        else {
                            return
                        }
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
                    }
                })
                
                self.navigationController?.popToRootViewController(animated: true)
            }
        })
    }
    
    private func alertLoginError(with message: String = "Please enter all info to create a new account.") {
        let alert = UIAlertController(title: "Ooops!", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }
}

extension RegisterViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        switch textField {
        case firstNameField : lastNameField.becomeFirstResponder()
        case lastNameField : emailField.becomeFirstResponder()
        case emailField: passwordField.becomeFirstResponder()
        case passwordField: registerButtonTapped()
        default : break
        }
        
        return true
    }
}

extension RegisterViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.editedImage] as? UIImage else { return }
        
        self.imageView.image = image
    }
    
    func presentPhotoActionSheet() {
        let ac = UIAlertController(title: "Profile picture",
                                   message: "How would you like to select a picture?",
                                   preferredStyle: .actionSheet)
        
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        ac.addAction(UIAlertAction(title: "Take Photo", style: .default) { [weak self] _ in self?.pickImage(from: .camera) })
        ac.addAction(UIAlertAction(title: "Choose Photo", style: .default) { [weak self] _ in self?.pickImage(from: .photoLibrary) })
        
        present(ac, animated: true)
    }
    
    func pickImage(from source: UIImagePickerController.SourceType) {
        let vc = UIImagePickerController()
        vc.sourceType = source
        vc.delegate = self
        vc.allowsEditing = true
        present(vc, animated: true)
    }
}
