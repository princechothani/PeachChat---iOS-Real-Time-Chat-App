//
//  ChatApp_mainApp.swift
//  ChatApp-main
//
//  Created by Prince Chothani on 06/06/25.
//

import SwiftUI
import Firebase

@main
struct ChatApp_mainApp: App {
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}

struct MainView: View {
    @StateObject private var authManager = AuthManager()
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                ChatListView()
                    .environmentObject(authManager)
            } else {
                LoginView()
                    .environmentObject(authManager)
            }
        }
        .onAppear {
            // Check authentication status
            if authManager.currentUser != nil {
                authManager.isAuthenticated = true
            }
        }
    }
}
