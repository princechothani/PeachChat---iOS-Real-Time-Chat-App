//
//  ChatListView.swift
//  ChatApp-main
//
//  Created by Prince Chothani on 08/06/25.
//

import SwiftUI
import FirebaseFirestore

struct ChatListView: View {
    @StateObject private var chatManager = ChatManager()
    @EnvironmentObject var authManager: AuthManager
    @State private var showingNewChat = false
    @State private var searchText = ""
    
    var filteredChats: [Chat] {
        if searchText.isEmpty {
            return chatManager.chats
        } else {
            return chatManager.chats.filter { chat in
                chat.lastMessage.localizedCaseInsensitiveContains(searchText) ||
                (chat.groupName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search chats...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                if chatManager.isLoading {
                    Spacer()
                    ProgressView("Loading chats...")
                        .progressViewStyle(CircularProgressViewStyle())
                    Spacer()
                } else if filteredChats.isEmpty {
                    Spacer()
                    VStack(spacing: 20) {
                        Image(systemName: "message.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text(searchText.isEmpty ? "No chats yet" : "No chats found")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                        
                        if searchText.isEmpty {
                            Text("Start a new conversation to begin chatting")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                    }
                    Spacer()
                } else {
                    List(filteredChats) { chat in
                        ChatRowView(chat: chat)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        authManager.signOut()
                    }) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.red)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingNewChat = true
                    }) {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(Color("Peach"))
                    }
                }
            }
        }
        .sheet(isPresented: $showingNewChat) {
            NewChatView(chatManager: chatManager)
        }
        .onAppear {
            if let currentUser = authManager.currentUser {
                chatManager.setCurrentUser(currentUser.id)
            }
        }
        .onReceive(authManager.$currentUser) { user in
            if let user = user {
                chatManager.setCurrentUser(user.id)
            }
        }
        .environmentObject(chatManager)
    }
}

struct ChatRowView: View {
    let chat: Chat
    @State private var otherUser: User?
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        NavigationLink(destination: ChatDetailView(chat: chat)) {
            HStack(spacing: 12) {
                // Profile image
                ZStack {
                    Circle()
                        .fill(Color("Peach"))
                        .frame(width: 50, height: 50)
                    
                    if let imageUrl = chat.groupImageUrl ?? otherUser?.profileImageUrl {
                        AsyncImage(url: URL(string: imageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: chat.isGroupChat ? "person.3.fill" : "person.fill")
                                .foregroundColor(.white)
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: chat.isGroupChat ? "person.3.fill" : "person.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                    
                    // Online indicator
                    if otherUser?.isOnline == true {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                            .offset(x: 18, y: 18)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(chat.isGroupChat ? (chat.groupName ?? "Group Chat") : (otherUser?.username ?? "Unknown"))
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(formatTimestamp(chat.lastMessageTime))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text(chat.lastMessage.isEmpty ? "No messages yet" : chat.lastMessage)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if chat.unreadCount > 0 {
                            Text("\(chat.unreadCount)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(Color.red)
                                .clipShape(Circle())
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .onAppear(perform: fetchOtherUser)
    }
    
    private func fetchOtherUser() {
        guard !chat.isGroupChat, let currentUserId = authManager.currentUser?.id else { return }
        guard let otherUserId = chat.participants.first(where: { $0 != currentUserId }) else { return }
        
        let db = Firestore.firestore()
        db.collection("users").document(otherUserId).getDocument { snapshot, error in
            if let data = snapshot?.data() {
                do {
                    let json = try JSONSerialization.data(withJSONObject: data)
                    var user = try JSONDecoder().decode(User.self, from: json)
                    user.id = otherUserId
                    self.otherUser = user
                } catch {
                    print("Failed to decode other user: \(error)")
                }
            }
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

struct NewChatView: View {
    @ObservedObject var chatManager: ChatManager
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var users: [User] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search users...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                if isLoading {
                    Spacer()
                    ProgressView("Loading users...")
                    Spacer()
                } else if users.isEmpty {
                    Spacer()
                    Text("No users found")
                        .foregroundColor(.gray)
                    Spacer()
                } else {
                    List(users) { user in
                        Button(action: {
                            chatManager.createChat(with: user.id)
                            dismiss()
                        }) {
                            HStack {
                                // User avatar
                                ZStack {
                                    Circle()
                                        .fill(Color("Peach"))
                                        .frame(width: 40, height: 40)
                                    
                                    if let imageUrl = user.profileImageUrl {
                                        AsyncImage(url: URL(string: imageUrl)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Image(systemName: "person.fill")
                                                .foregroundColor(.white)
                                        }
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                    } else {
                                        Image(systemName: "person.fill")
                                            .foregroundColor(.white)
                                    }
                                    
                                    if user.isOnline {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 10, height: 10)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.white, lineWidth: 2)
                                            )
                                            .offset(x: 15, y: 15)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.username)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text(user.email)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Load users (this would typically fetch from Firestore)
            loadUsers()
        }
    }
    
    private func loadUsers() {
        isLoading = true
        
        // Fetch real users from Firestore
        let db = Firestore.firestore()
        db.collection("users").getDocuments { snapshot, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    print("Error fetching users: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No users found")
                    return
                }
                
                self.users = documents.compactMap { document in
                    do {
                        let data = document.data()
                        let jsonData = try JSONSerialization.data(withJSONObject: data)
                        var user = try JSONDecoder().decode(User.self, from: jsonData)
                        user.id = document.documentID
                        
                        // Don't show current user in the list
                        if user.id == self.chatManager.currentUserId {
                            return nil
                        }
                        
                        return user
                    } catch {
                        print("Error decoding user: \(error)")
                        return nil
                    }
                }
            }
        }
    }
}

#Preview {
    ChatListView()
}
