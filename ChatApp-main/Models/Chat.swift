//
//  Chat.swift
//  ChatApp-main
//
//  Created by Prince Chothani on 08/06/25.
//

import Foundation
import FirebaseFirestore

struct Chat: Identifiable, Codable {
    var id: String
    var participants: [String] // User IDs
    var lastMessage: String
    var lastMessageTime: Date
    var lastMessageSenderId: String
    var unreadCount: Int
    var isGroupChat: Bool
    var groupName: String?
    var groupImageUrl: String?
    
    init(id: String, participants: [String], isGroupChat: Bool = false, groupName: String? = nil) {
        self.id = id
        self.participants = participants
        self.lastMessage = ""
        self.lastMessageTime = Date()
        self.lastMessageSenderId = ""
        self.unreadCount = 0
        self.isGroupChat = isGroupChat
        self.groupName = groupName
        self.groupImageUrl = nil
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case participants
        case lastMessage
        case lastMessageTime
        case lastMessageSenderId
        case unreadCount
        case isGroupChat
        case groupName
        case groupImageUrl
    }
    
    // Custom decoder to handle ISO8601 date strings
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        participants = try container.decode([String].self, forKey: .participants)
        lastMessage = try container.decode(String.self, forKey: .lastMessage)
        lastMessageSenderId = try container.decode(String.self, forKey: .lastMessageSenderId)
        unreadCount = try container.decode(Int.self, forKey: .unreadCount)
        isGroupChat = try container.decode(Bool.self, forKey: .isGroupChat)
        groupName = try container.decodeIfPresent(String.self, forKey: .groupName)
        groupImageUrl = try container.decodeIfPresent(String.self, forKey: .groupImageUrl)
        
        // Handle timestamp decoding from ISO8601 string
        if let timestampString = try? container.decode(String.self, forKey: .lastMessageTime) {
            let formatter = ISO8601DateFormatter()
            lastMessageTime = formatter.date(from: timestampString) ?? Date()
        } else {
            lastMessageTime = Date()
        }
    }
}
