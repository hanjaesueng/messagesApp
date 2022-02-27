//
//  ConversationModels.swift
//  MessagerPractice
//
//  Created by 김현미 on 2022/02/27.
//

import Foundation

struct Conversation {
    let id : String
    let name : String
    let otherUserEmail : String
    let latestMessage : LatestMessage
}

struct LatestMessage {
    let date : String
    let text : String
    let isRead : Bool
}
