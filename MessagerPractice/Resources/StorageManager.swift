//
//  StorageManager.swift
//  MessagerPractice
//
//  Created by 김현미 on 2022/02/15.
//

import Foundation
import FirebaseStorage

final class StorageManager {
    static let shared = StorageManager()
    private init(){}
    
    private let storage = Storage.storage().reference()
    
    /**
            /images/afraz9-gmail-com_profile_picture.png
     */
    public typealias UploadPictureCompletion = (Result<String, StorageErrors>)->()
    
    /// Uploads picture to firebase storage
    public func uploadProfilePicture(with data: Data,fileName: String,completion :@escaping UploadPictureCompletion){
        storage.child("images/\(fileName)").putData(data,metadata: nil) { metaData, error in
            guard error == nil else {
                print("failed to upload data to firebase for picture")
                completion(.failure(.failedToUpload))
                return
            }
            
            self.storage.child("images/\(fileName)").downloadURL { url, error in
                guard let url = url else {
                    print("Failed to get download url")
                    completion(.failure(.failedToGetDownloadUrl))
                    return
                }
                
                let urlString = url.absoluteString
                print("downloaded url returned : \(urlString)")
                completion(.success(urlString))
            }
        }
    }
    
    public enum StorageErrors : Error {
        case failedToUpload
        case failedToGetDownloadUrl
    }
    
    public func downloadURL(for path: String, completion : @escaping (Result<URL,StorageErrors>) -> Void) {
        let reference = storage.child(path)
        
        reference.downloadURL { url, error in
            guard let url = url, error == nil else {
                completion(.failure(.failedToGetDownloadUrl))
                return
            }
            completion(.success(url))
        }
    }
}
