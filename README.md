# ChatApp - Real-time Messaging

## Features Added

### Real-time Messaging
- Messages sent from one device appear instantly on other devices
- Message status indicators (sent, delivered, read)
- Real-time chat list updates
- User authentication with Firebase

## How to Test Real-time Messaging

### Step 1: Create Multiple Accounts
1. Run the app on two different devices/simulators
2. Sign up with different email addresses on each device
3. Example accounts:
   - Device 1: `user1@test.com` / `password123`
   - Device 2: `user2@test.com` / `password123`

### Step 2: Start a Chat
1. On Device 1, tap the pencil icon (top-right) to create a new chat
2. Select the user from Device 2 from the list
3. The chat will appear in both devices' chat lists

### Step 3: Send Messages
1. Type a message in Device 1 and tap send
2. The message will appear instantly on Device 2
3. Message status will show: ✓ (sent) → ✓○ (delivered) → ✓● (read)

### Step 4: Test Real-time Features
- Send messages from both devices
- Messages appear in real-time without refreshing
- Chat list updates automatically with latest messages
- Message status updates in real-time

## Firebase Setup Required

### Firestore Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null;
    }
    match /chats/{chatId} {
      allow read, write: if request.auth != null && 
        request.auth.uid in resource.data.participants;
      match /messages/{messageId} {
        allow read, write: if request.auth != null && 
          get(/databases/$(database)/documents/chats/$(chatId)).data.participants[request.auth.uid] != null;
      }
    }
  }
}
```

### Required Index
- Collection: `chats`
- Fields: `participants` (array-contains), `lastMessageTime` (descending)
- Query scope: Collection

## Technical Details

### Real-time Features
- Uses Firestore `addSnapshotListener` for real-time updates
- Optimistic UI updates for better user experience
- Message status tracking (sent → delivered → read)
- Automatic read receipts when messages are viewed

### Data Structure
```
users/{userId} - User profiles
chats/{chatId} - Chat metadata
chats/{chatId}/messages/{messageId} - Individual messages
```

### Message Flow
1. User types message → Optimistic UI update
2. Message sent to Firestore → Status: "sent"
3. Other device receives via listener → Status: "delivered"
4. User opens chat → Status: "read"

## Troubleshooting

### Messages not appearing
- Check Firebase Console → Firestore → Data
- Verify Firestore rules allow read/write
- Ensure composite index is built

### Users not showing in New Chat
- Check if users are created in `users` collection
- Verify authentication is working
- Check console for Firestore errors

### Real-time not working
- Check internet connection
- Verify Firebase project configuration
- Check `GoogleService-Info.plist` is correct
