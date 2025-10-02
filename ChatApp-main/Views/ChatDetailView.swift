//
//  ChatDetailView.swift
//  ChatApp-main
//
//  Created by Prince Chothani on 08/06/25.
//

import SwiftUI
import PhotosUI
import UIKit

struct ChatDetailView: View {
    let chat: Chat
    @EnvironmentObject var chatManager: ChatManager
    @EnvironmentObject var authManager: AuthManager
    @State private var messageText = ""
    @State private var showingImagePicker = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var showingOptions = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            messagesArea
            inputArea
        }
        .navigationTitle(chat.isGroupChat ? (chat.groupName ?? "Group Chat") : "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // Show chat info
                }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(Color("Peach"))
                }
            }
        }
        .onAppear {
            chatManager.fetchMessages(for: chat.id)
        }
        .actionSheet(isPresented: $showingOptions) {
            ActionSheet(
                title: Text("Add to chat"),
                buttons: [
                    .default(Text("Photo")) {
                        showingImagePicker = true
                    },
                    .default(Text("Camera")) {
                        // Camera functionality
                    },
                    .default(Text("Document")) {
                        // Document picker
                    },
                    .cancel()
                ]
            )
        }
        .photosPicker(isPresented: $showingImagePicker,
                       selection: $selectedItem,
                       matching: .images,
                       preferredItemEncoding: .automatic,
                       photoLibrary: .shared())
        .onChange(of: selectedItem) { newItem in
            guard let newItem = newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        chatManager.sendImageMessage(image, to: chat.id)
                        selectedItem = nil
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(chatManager.messages) { message in
                        MessageBubbleView(
                            message: message,
                            isFromCurrentUser: message.senderId == authManager.currentUser?.id
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
            }
            .onChange(of: chatManager.messages.count) { _ in
                if let lastMessage = chatManager.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var inputArea: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                // Attachment button
                Button(action: {
                    showingOptions = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color("Peach"))
                }
                
                // Message input field
                HStack {
                    TextField("Type a message...", text: $messageText, axis: .vertical)
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($isTextFieldFocused)
                        .lineLimit(1...4)
                    
                    if !messageText.isEmpty {
                        Button(action: {
                            messageText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(20)
                
                // Send button
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 35, height: 35)
                        .background(messageText.isEmpty ? Color.gray : Color("Peach"))
                        .clipShape(Circle())
                }
                .disabled(messageText.isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Methods
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        chatManager.sendMessage(trimmedText, to: chat.id)
        messageText = ""
        isTextFieldFocused = false
    }
}

struct MessageBubbleView: View {
    let message: Message
    let isFromCurrentUser: Bool
    @State private var showingTime = false
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                messageContent
                
                // Timestamp
                if showingTime {
                    Text(formatTimestamp(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)
                }
                
                // Message status (for sent messages)
                if isFromCurrentUser {
                    messageStatus
                }
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 50)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var messageContent: some View {
        Group {
            switch message.messageType {
            case .text:
                Text(message.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(isFromCurrentUser ? Color("Peach") : Color(.systemGray5))
                    .foregroundColor(isFromCurrentUser ? .white : .primary)
                    .cornerRadius(18)
                
            case .image:
                if let imageUrl = message.mediaUrl {
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 200, maxHeight: 200)
                            .cornerRadius(12)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray5))
                            .frame(width: 200, height: 200)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            )
                    }
                }
                
            case .video:
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .frame(width: 200, height: 120)
                    .overlay(
                        VStack {
                            Image(systemName: "play.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                            Text("Video")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    )
                
            case .audio:
                HStack {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                    Text("Audio Message")
                        .font(.subheadline)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isFromCurrentUser ? Color("Peach") : Color(.systemGray5))
                .foregroundColor(isFromCurrentUser ? .white : .primary)
                .cornerRadius(18)
                
            case .file:
                HStack {
                    Image(systemName: "doc.fill")
                        .font(.title2)
                    Text("Document")
                        .font(.subheadline)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isFromCurrentUser ? Color("Peach") : Color(.systemGray5))
                .foregroundColor(isFromCurrentUser ? .white : .primary)
                .cornerRadius(18)
                
            case .location:
                HStack {
                    Image(systemName: "location.fill")
                        .font(.title2)
                    Text("Location")
                        .font(.subheadline)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isFromCurrentUser ? Color("Peach") : Color(.systemGray5))
                .foregroundColor(isFromCurrentUser ? .white : .primary)
                .cornerRadius(18)
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                showingTime.toggle()
            }
        }
    }
    
    private var messageStatus: some View {
        HStack(spacing: 2) {
            switch message.status {
            case .sent:
                Image(systemName: "checkmark")
                    .font(.caption2)
                    .foregroundColor(.gray)
            case .delivered:
                Image(systemName: "checkmark.circle")
                    .font(.caption2)
                    .foregroundColor(.gray)
            case .read:
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.blue)
            case .failed:
                Image(systemName: "exclamationmark.circle")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
        .padding(.trailing, 8)
    }
    
    // MARK: - Methods
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationView {
        ChatDetailView(chat: Chat(id: "1", participants: ["user1", "user2"]))
            .environmentObject(ChatManager())
            .environmentObject(AuthManager())
    }
}
