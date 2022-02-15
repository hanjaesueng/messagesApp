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
    
    //check exists
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
    
    // all users load for message
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

// MARK: - Sending messages / conversations
extension DatabaseManager {
    
    /*
     "unique id" => {
        "messages":[
            "id":String
            "type": text,phot,video
            "content":String
            "date":Date()
            "sender_email":String
            "isRead":true/false
        ]
     }
     
     conversations => [
        [
            "conversation_id": "unique id"
            "other_user_email":
            "latest_message" => {
                "date":Date()
                "latest_message" : "message"
                "is_read" : true/false
            }
        ],
     ]
     */
    /// Create a new conversation with target user email and first message sent
    public func createNewConversation(with otherUserEmail: String, firstMessage : Message, completion : @escaping (Bool) -> Void) {
        guard let currentEmail = UserDefaults.standard.string(forKey: "email") else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(email: currentEmail)
        let ref = database.child(safeEmail)
        ref.observeSingleEvent(of: .value) { sanpShot in
            guard var userNode = sanpShot.value as? [String:Any] else {
                completion(false)
                print("user not found")
                return
            }
            
            let messageDate = firstMessage.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            
            var message = ""
            
            switch firstMessage.kind {
                
            case .text(let messageText):
                message = messageText
            case .attributedText(_):
                break
            case .photo(_):
                break
            case .video(_):
                break
            case .location(_):
                break
            case .emoji(_):
                break
            case .audio(_):
                break
            case .contact(_):
                break
            case .linkPreview(_):
                break
            case .custom(_):
                break
            }
            
            let conversationID = "conversation_\(firstMessage.messageId)"
            let  newConversationData = ["id":conversationID,"other_user_email":otherUserEmail,"latest_message":[
                "date":dateString,
                "latest_message":message,
                "is_read":false
            ]] as [String : Any]
            
            if var conversations = userNode["conversations"] as? [[String:Any]] {
                //conversation array exists for current user
                // you sould appen
                conversations.append(newConversationData)
                userNode["conversations"] = conversations
                ref.setValue(userNode) {[weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(conversationID: conversationID, firstMessage: firstMessage, completion: completion)
                }
            } else {
                //conversation array does not Exist
                //create
                userNode["conversations"] = [
                    newConversationData
                ]
                ref.setValue(userNode) {[weak self] error, _ in
                    guard error == nil else {
                        completion(false)
                        return
                    }
                    self?.finishCreatingConversation(conversationID: conversationID, firstMessage: firstMessage, completion: completion)
                    
                }
            }
        }
    }
    
    private func finishCreatingConversation(conversationID : String, firstMessage : Message, completion: @escaping (Bool)->Void){
//        "messages":[
//            "id":String
//            "type": text,phot,video
//            "content":String
//            "date":Date()
//            "sender_email":String
//            "isRead":true/false
//        ]
        
        let messageDate = firstMessage.sentDate
        let dateString = ChatViewController.dateFormatter.string(from: messageDate)
        
        var messageContent = ""
        
        switch firstMessage.kind {
            
        case .text(let messageText):
            messageContent = messageText
        case .attributedText(_):
            break
        case .photo(_):
            break
        case .video(_):
            break
        case .location(_):
            break
        case .emoji(_):
            break
        case .audio(_):
            break
        case .contact(_):
            break
        case .linkPreview(_):
            break
        case .custom(_):
            break
        }
        guard let myEmail = UserDefaults.standard.string(forKey: "email") else {
            completion(false)
            return
        }
        let currentUserEmail = DatabaseManager.safeEmail(email: myEmail)
        let message : [String:Any] = [
            "id":firstMessage.messageId,
            "type":firstMessage.kind.messageKindString,
            "content":messageContent,
            "date":dateString,
            "sender_email": currentUserEmail,
            "false":false
        ]
        let value : [String : Any] = [
            "messages" : [
                message
            ]
        ]
        
        print("adding convo : \(conversationID)")
        database.child(conversationID).setValue(value) { error, _ in
            guard error == nil else {
                completion(false)
                return
            }
            completion(true)
        }
    }
    
    /// Fetches and returns all conversations for the user with passed in email
    public func getAllConversations(for email : String, completion : @escaping (Result<String,Error>) -> Void){
        
    }
    
    /// Gets all messages for a given conversation
    public func getAllMessagesForConversation(with id : String, completion : @escaping (Result<String,Error>) -> Void) {
        
    }
    
    /// Sends a message with target conversation and message
    public func sendMessage(to conversation : String, message : Message,completion : @escaping (Bool) -> Void) {
        
    }
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
