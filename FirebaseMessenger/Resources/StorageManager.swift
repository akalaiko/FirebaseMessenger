//
//  StorageManager.swift
//  FirebaseMessenger
//
//  Created by Tim on 25.01.2023.
//

import Foundation
import FirebaseStorage

final class StorageManager {
    
    static let shared = StorageManager()
    
    private let storage = Storage.storage().reference()
    
    public typealias completionBlock = (Result<String, Error>) -> Void
    
    /// Upload picture to firebase storage and return url string to download
    public func uploadProfilePicture(with data: Data, fileName: String, completion: @escaping completionBlock) {
        storage.child("images/\(fileName)").putData(data) { [weak self] metadata, error in
            guard let self else { return }
            guard error == nil else {
                print("failed to upload data to firebase")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            
            self.storage.child("images/\(fileName)").downloadURL() { url, error in
                guard let url else {
                    print("failed to get download url")
                    completion(.failure(StorageErrors.failedToGetDownloadURL))
                    return
                }
                
                let urlString = url.absoluteString
                print("download url returned:", urlString)
                completion(.success(urlString))
            }
        }
    }
    /// upload image that will be sent in a conversation message
    public func uploadMessagePhoto(with data: Data, fileName: String, completion: @escaping completionBlock) {
        storage.child("message_images/\(fileName)").putData(data) { [weak self] metadata, error in
            guard let self else { return }
            guard error == nil else {
                print("failed to upload data to firebase")
                completion(.failure(StorageErrors.failedToUpload))
                return
            }
            
            self.storage.child("message_images/\(fileName)").downloadURL() { url, error in
                guard let url else {
                    print("failed to get download url")
                    completion(.failure(StorageErrors.failedToGetDownloadURL))
                    return
                }
                
                let urlString = url.absoluteString
                print("download url returned:", urlString)
                completion(.success(urlString))
            }
        }
    }
    
    public enum StorageErrors: Error {
        case failedToUpload
        case failedToGetDownloadURL
    }
    
    public func downloadURL(for path: String, completion: @escaping completionBlock) {
        
        storage.child(path).downloadURL(completion: { url, error in
            guard let url, error == nil else {
                print("failed to get download url")
                completion(.failure(StorageErrors.failedToGetDownloadURL))
                return
            }
            
            let urlString = url.absoluteString
            print("download url returned:", urlString)
            completion(.success(urlString))
        })
    }
}
