//
//  User.swift
//  ChatApp-main
//
//  Created by Prince Chothani on 08/06/25.
//

import Foundation
import FirebaseFirestore

struct User: Identifiable, Codable {
    var id: String
    var email: String
    var username: String
    var profileImageUrl: String?
    var isOnline: Bool
    var lastSeen: Date
    
    init(id: String, email: String, username: String, profileImageUrl: String? = nil) {
        self.id = id
        self.email = email
        self.username = username
        self.profileImageUrl = profileImageUrl
        self.isOnline = true
        self.lastSeen = Date()
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username
        case profileImageUrl
        case isOnline
        case lastSeen
    }
}
