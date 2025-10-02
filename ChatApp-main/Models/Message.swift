//
//  Message.swift
//  ChatApp-main
//
//  Created by Prince Chothani on 07/06/25.
//

import Foundation
import FirebaseFirestore

struct Message: Identifiable, Codable, Hashable {
    var id: String
    var text: String
    var senderId: String
    var chatId: String
    var timestamp: Date
    var messageType: MessageType
    var status: MessageStatus
    var replyToMessageId: String?
    var mediaUrl: String?
    var mediaType: MediaType?
    
    enum MessageType: String, Codable, CaseIterable {
        case text = "text"
        case image = "image"
        case video = "video"
        case audio = "audio"
        case file = "file"
        case location = "location"
    }
    
    enum MessageStatus: String, Codable, CaseIterable {
        case sent = "sent"
        case delivered = "delivered"
        case read = "read"
        case failed = "failed"
    }
    
    enum MediaType: String, Codable, CaseIterable {
        case image = "image"
        case video = "video"
        case audio = "audio"
        case file = "file"
    }
    
    init(id: String, text: String, senderId: String, chatId: String, timestamp: Date = Date(), messageType: MessageType = .text, status: MessageStatus = .sent) {
        self.id = id
        self.text = text
        self.senderId = senderId
        self.chatId = chatId
        self.timestamp = timestamp
        self.messageType = messageType
        self.status = status
        self.replyToMessageId = nil
        self.mediaUrl = nil
        self.mediaType = nil
    }
    
    // Computed property for backward compatibility
    var received: Bool {
        return senderId != "currentUser" // This will be updated with actual user ID
    }
    
    // Custom decoder to handle ISO8601 date strings
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        senderId = try container.decode(String.self, forKey: .senderId)
        chatId = try container.decode(String.self, forKey: .chatId)
        messageType = try container.decode(MessageType.self, forKey: .messageType)
        status = try container.decode(MessageStatus.self, forKey: .status)
        replyToMessageId = try container.decodeIfPresent(String.self, forKey: .replyToMessageId)
        mediaUrl = try container.decodeIfPresent(String.self, forKey: .mediaUrl)
        mediaType = try container.decodeIfPresent(MediaType.self, forKey: .mediaType)
        
        // Handle timestamp decoding from ISO8601 string
        if let timestampString = try? container.decode(String.self, forKey: .timestamp) {
            let formatter = ISO8601DateFormatter()
            timestamp = formatter.date(from: timestampString) ?? Date()
        } else {
            timestamp = Date()
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, text, senderId, chatId, timestamp, messageType, status
        case replyToMessageId, mediaUrl, mediaType
    }
}
