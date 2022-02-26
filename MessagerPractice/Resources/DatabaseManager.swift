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

extension DatabaseManager {
    public func getDataFor(path : String, completion : @escaping (Result<Any,Error>) -> Void) {
        self.database.child(path).observeSingleEvent(of: .value) { snapShot in
            guard let value = snapShot.value else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            completion(.success(value))
        }
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
    public func createNewConversation(with otherUserEmail: String,name : String, firstMessage : Message, completion : @escaping (Bool) -> Void) {
        guard let currentEmail = UserDefaults.standard.string(forKey: "email"),
              let currentName = UserDefaults.standard.string(forKey: "name") else {
            return
        }
        let safeEmail = DatabaseManager.safeEmail(email: currentEmail)
        let ref = database.child(safeEmail)
        ref.observeSingleEvent(of: .value) {[weak self] sanpShot in
            guard var userNode = sanpShot.value as? [String:Any] else {
                completion(false)
                print("user not found")
                return
            }
            print(userNode)
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
            let  newConversationData = ["id":conversationID,
                                        "other_user_email":otherUserEmail,
                                        "name" : name,
                                        "latest_message":[
                                            "date":dateString,
                                            "message":message,
                                            "is_read":false
                                        ]] as [String : Any]
            
            let  recipient_newConversationData = ["id":conversationID,
                                                  "other_user_email":safeEmail,
                                                  "name" : currentName,
                                                  "latest_message":[
                                                    "date":dateString,
                                                    "message":message,
                                                    "is_read":false
                                                  ]] as [String : Any]
            
            //Update recipient conversation entry
            
            self?.database.child("\(otherUserEmail)/conversations").observeSingleEvent(of: .value) {snapShot in
                if var conversataions = snapShot.value as? [[String:Any]] {
                    //append
                    conversataions.append(recipient_newConversationData)
                    self?.database.child("\(otherUserEmail)/conversations").setValue(conversataions)
                } else {
                    self?.database.child("\(otherUserEmail)/conversations").setValue([recipient_newConversationData])
                }
            }
           
            // The update current user conversation entry
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
                    self?.finishCreatingConversation(name : name,conversationID: conversationID, firstMessage: firstMessage, completion: completion)
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
                    self?.finishCreatingConversation(name : name,conversationID: conversationID, firstMessage: firstMessage, completion: completion)
                    
                }
            }
        }
    }
    
    private func finishCreatingConversation(name:String,conversationID : String, firstMessage : Message, completion: @escaping (Bool)->Void){
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
            "is_read":false,
            "name" : name
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
    public func getAllConversations(for email : String, completion : @escaping (Result<[Conversation],Error>) -> Void){
        database.child("\(email)/conversations").observe(.value) { sanpShot in
            guard let value = sanpShot.value as? [[String:Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            print(value)
            let conversations : [Conversation] = value.compactMap { dictionary in
                guard let conversationId = dictionary["id"] as? String,
                      let otherUserEmail = dictionary["other_user_email"] as? String,
                      let latestMessage = dictionary["latest_message"] as? [String:Any],
                      let name = dictionary["name"] as? String,
                      let date = latestMessage["date"] as? String,
                      let message = latestMessage["message"] as? String,
                      let isRead = latestMessage["is_read"] as? Bool else {
                          return nil
                      }
                let latestMessageObject = LatestMessage(date: date, text: message, isRead: isRead)
                return Conversation(id: conversationId, name: name, otherUserEmail: otherUserEmail, latestMessage: latestMessageObject)
            }
            completion(.success(conversations))
        }
    }
    
    /// Gets all messages for a given conversation
    public func getAllMessagesForConversation(with id : String, completion : @escaping (Result<[Message],Error>) -> Void) {
        database.child("\(id)/messages").observe(.value) { sanpShot in
            guard let value = sanpShot.value as? [[String:Any]] else {
                completion(.failure(DatabaseError.failedToFetch))
                return
            }
            print(value)
            let messages : [Message] = value.compactMap { dictionary in
                guard let name = dictionary["name"] as? String,
                      let isRead = dictionary["is_read"] as? Bool,
                      let messageID = dictionary["id"] as? String,
                      let content = dictionary["content"] as? String,
                      let senderEmail = dictionary["sender_email"] as? String,
                      let type = dictionary["type"] as? String,
                      let dateString = dictionary["date"] as? String,
                      let date = ChatViewController.dateFormatter.date(from: dateString) else {
                          return nil
                      }
                
                let sender = Sender(photoURL: "", senderId: senderEmail, displayName: name)
                return Message(sender: sender, messageId: messageID, sentDate: date, kind: .text(content))
            }
            completion(.success(messages))
        }
    }
    
    /// Sends a message with target conversation and message
    public func sendMessage(to conversationID : String,otheruserEmail: String,name : String,message : Message,completion : @escaping (Bool) -> Void) {
        // add new message to messages
        // update sender latest message
        // update recipient latest message
        
        guard let myEmail = UserDefaults.standard.string(forKey: "email") else {
            completion(false)
            return
        }
        let currentEmail = DatabaseManager.safeEmail(email: myEmail)
        self.database.child("\(conversationID)/messages").observeSingleEvent(of: .value) {[weak self] snapshot in
            guard let self = self else {return}
            guard var currentMessages = snapshot.value as? [[String : Any]] else {
                completion(false)
                return
            }
            let messageDate = message.sentDate
            let dateString = ChatViewController.dateFormatter.string(from: messageDate)
            
            var messageContent = ""
            
            switch message.kind {
                
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
            let newMessageEntry : [String:Any] = [
                "id":message.messageId,
                "type":message.kind.messageKindString,
                "content":messageContent,
                "date":dateString,
                "sender_email": currentUserEmail,
                "is_read":false,
                "name" : name
            ]
            currentMessages.append(newMessageEntry)
            self.database.child("\(conversationID)/messages").setValue(currentMessages) { error, _ in
                guard error == nil else {
                    completion(false)
                    return
                }
                
                self.database.child("\(currentEmail)/conversations").observeSingleEvent(of: .value) { snapshot in
                    guard var currentUserConversations = snapshot.value as? [[String:Any]] else {
                        completion(false)
                        return
                    }
                    
                    let updatedValue : [String:Any] = [
                        "date":dateString,
                        "is_read":false,
                        "message":messageContent
                    ]
                    
                    var targetConversation : [String:Any]?
                    var position = 0
                    
                    // searching latest message
                    for conversation in currentUserConversations {
                        if let currentID = conversation["id"] as? String, currentID == conversationID {
                            targetConversation = conversation
                            break
                        }
                        position += 1
                    }
                    targetConversation?["latest_message"] = updatedValue
                    guard let targetConversation = targetConversation else {
                        completion(false)
                        return
                    }

                    currentUserConversations[position] = targetConversation
                    self.database.child("\(currentEmail)/conversations").setValue(currentUserConversations) { error, _ in
                        guard error == nil else {
                            completion(false)
                            return
                        }
                        
                        // Update latest message for recipient user
                        
                        self.database.child("\(otheruserEmail)/conversations").observeSingleEvent(of: .value) { snapshot in
                            
                            guard var otherUserConversations = snapshot.value as? [[String:Any]] else {
                                completion(false)
                                return
                            }
                            
                            let updatedValue : [String:Any] = [
                                "date":dateString,
                                "is_read":false,
                                "message":messageContent
                            ]
                            
                            var targetConversation : [String:Any]?
                            var position = 0
                            
                            // searching latest message
                            for conversation in otherUserConversations {
                                if let currentID = conversation["id"] as? String, currentID == conversationID {
                                    targetConversation = conversation
                                    break
                                }
                                position += 1
                            }
                            targetConversation?["latest_message"] = updatedValue
                            guard let targetConversation = targetConversation else {
                                completion(false)
                                return
                            }

                            otherUserConversations[position] = targetConversation
                            self.database.child("\(otheruserEmail)/conversations").setValue(otherUserConversations) { error, _ in
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
        }
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
