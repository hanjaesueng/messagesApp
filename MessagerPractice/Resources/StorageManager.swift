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
    

    /// Upload video that will be sent in a conversation message
    public func uploadMessageVideo(with fileUrl: URL,fileName: String,completion :@escaping UploadPictureCompletion){
        print(fileName)
        print(fileUrl)
        storage.child("message_videos/\(fileName)").putFile(from: fileUrl,metadata: nil) { metaData, error in
            guard error == nil else {
                print("failed to upload video file to firebase for video")
                print(error?.localizedDescription)
                completion(.failure(.failedToUpload))
                return
            }
            
            self.storage.child("message_videos/\(fileName)").downloadURL { url, error in
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
    /// Upload image that will be sent in a conversation message
    public func uploadMessagePhoto(with data: Data,fileName: String,completion :@escaping UploadPictureCompletion){
        storage.child("message_images/\(fileName)").putData(data,metadata: nil) {[weak self] metaData, error in
            guard error == nil else {
                print("failed to upload data to firebase for picture")
                completion(.failure(.failedToUpload))
                return
            }
            
            self?.storage.child("message_images/\(fileName)").downloadURL { url, error in
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
