//
//  StorageManager.swift
//  FirebaseMessenger
//
//  Created by Tim on 25.01.2023.
//

import Foundation
import FirebaseStorage

final class StorageManager {
    
    public enum StorageErrors: Error {
        case failedToUpload
        case failedToGetDownloadURL
    }
    
    static let shared = StorageManager()
    private init() {}
    
    private let storage = Storage.storage().reference()

    typealias completionBlock = (Result<String, Error>) -> Void
    
    /// Upload picture to firebase storage and return url string to download
    public func uploadProfilePicture(with data: Data, fileName: String, completion: @escaping completionBlock) {
        storage.child("images/\(fileName)").putData(data) { [weak self] metadata, error in
            guard error == nil else { return completion(.failure(StorageErrors.failedToUpload)) }
            self?.storage.child("images/\(fileName)").downloadURL() { url, _ in
                guard let url else { return completion(.failure(StorageErrors.failedToGetDownloadURL)) }
                completion(.success(url.absoluteString))
            }
        }
    }
    
    /// upload image that will be sent in a conversation message
    public func uploadMessageMedia(with data: Data, fileName: String, completion: @escaping completionBlock) {
        storage.child("message_images/\(fileName)").putData(data) { [weak self] metadata, error in
            guard error == nil else { return completion(.failure(StorageErrors.failedToUpload)) }
            self?.storage.child("message_images/\(fileName)").downloadURL() { url, _ in
                guard let url else { return completion(.failure(StorageErrors.failedToGetDownloadURL)) }
                completion(.success(url.absoluteString))
            }
        }
    }

    public func downloadURL(for path: String, completion: @escaping completionBlock) {
        storage.child(path).downloadURL(completion: { url, error in
            guard let url, error == nil else { return completion(.failure(StorageErrors.failedToGetDownloadURL)) }
            completion(.success(url.absoluteString))
        })
    }
}
