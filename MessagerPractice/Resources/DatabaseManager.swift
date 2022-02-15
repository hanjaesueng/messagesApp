//
//  DatabaseManager.swift
//  MessagerPractice
//
//  Created by jaeseung han on 2022/02/07.
//

import Foundation
import FirebaseDatabase

final class DatabaseManager {
    
    static let shared = DatabaseManager()
    private let database = Database.database().reference()
    private init(){}
    
    static func safeEmail(email : String) -> String {
        var safeEmail = email.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
 
}

// MARK: - Account Management
extension DatabaseManager {
    
    public func userExists(with email : String,
                           completion : @escaping (Bool)->()) {
        var safeEmail = email.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        database.child(safeEmail).observeSingleEvent(of: .value) { snapshot in
            print("snapshot.value :",snapshot.value as? [String:String])
            guard snapshot.value as? [String:String] != nil else {
                completion(false)
                return
            }
            completion(true)
        }
    }
    
    /// Inserts new user to database
    public func insertUser(with user : ChatAppUser,completion : @escaping (Bool)->()) {

        database.child(user.safeEmail).setValue([
            "first_name":user.firstName,
            "last_name":user.lastName
        ]) { error, _ in
            guard error == nil else {
                completion(false)
                print("failed to write to database")
                return
            }
            
            
            self.database.child("users").observeSingleEvent(of: .value) { snapShot in
                print("check snapShot :",snapShot.value)
                if var usersCollection = snapShot.value as? [[String:String]] {
                    // append to user dictionary
                    let newElement = ["name":user.firstName + " " + user.lastName,"email":user.safeEmail]
                    
                    usersCollection.append(newElement)
                    self.database.child("users").setValue(usersCollection) { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    }
                } else {
                    // create that array
                    let newCollection : [[String:String]] = [
                        ["name":user.firstName + " " + user.lastName,
                         "email":user.safeEmail]
                    ]
                    self.database.child("users").setValue(newCollection) { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        completion(true)
                    }
                }
            }
            
            
        }
    }
    
    public func getAllUsers(completion : @escaping (Result<[[String:String]],DatabaseError>) -> Void){
        database.child("users").observeSingleEvent(of: .value) { snapShot in
            guard let value = snapShot.value as? [[String:String]] else {
                completion(.failure(.failedToFetch))
                return
            }
            completion(.success(value))
        }
    }
    
    public enum DatabaseError : Error {
        case failedToFetch
    }
    
    /*
     users => [
        [
            "name":
            "safe_email":
        ],
        [
            "name":
            "safe_email":
        ]
     ]
     */
}

struct ChatAppUser {
    let firstName : String
    let lastName : String
    let emailAddress : String
    var safeEmail : String {
        var safeEmail = emailAddress.replacingOccurrences(of: ".", with: "-")
        safeEmail = safeEmail.replacingOccurrences(of: "@", with: "-")
        return safeEmail
    }
    var profilePictureFileName : String {
        //afraz9-gmail-com_profile_picture.png
        return "\(safeEmail)_profile_picture.png"
    }
}
