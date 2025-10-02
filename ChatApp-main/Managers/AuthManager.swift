//
//  AuthManager.swift
//  ChatApp-main
//
//  Created by Prince Chothani on 08/06/25.
//

import Foundation
import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

class AuthManager: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    init() {
        setupAuthStateListener()
    }

    private func setupAuthStateListener() {
        auth.addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                if let user = user {
                    self?.fetchUserData(userId: user.uid)
                } else {
                    self?.currentUser = nil
                    self?.isAuthenticated = false
                }
            }
        }
    }

    func signUp(email: String, password: String, username: String) {
        isLoading = true
        errorMessage = nil

        auth.createUser(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error = error {
                    self?.errorMessage = self?.mapAuthError(error)
                    print("Auth signUp error: \(error) | mapped: \(self?.errorMessage ?? "-")")
                    return
                }

                guard let user = result?.user else {
                    self?.errorMessage = "Failed to create user"
                    return
                }

                let newUser = User(id: user.uid, email: email, username: username)
                self?.saveUserToFirestore(user: newUser)
            }
        }
    }

    func signIn(email: String, password: String) {
        isLoading = true
        errorMessage = nil

        auth.signIn(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error = error {
                    self?.errorMessage = self?.mapAuthError(error)
                    print("Auth signIn error: \(error) | mapped: \(self?.errorMessage ?? "-")")
                    return
                }

                // User data will be fetched by the auth state listener
            }
        }
    }

    func signOut() {
        do {
            try auth.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveUserToFirestore(user: User) {
        do {
            let data = try JSONEncoder().encode(user)
            let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

            db.collection("users").document(user.id).setData(dict) { [weak self] error in
                DispatchQueue.main.async {
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                    } else {
                        self?.currentUser = user
                        self?.isAuthenticated = true
                    }
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fetchUserData(userId: String) {
        db.collection("users").document(userId).getDocument { [weak self] document, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }

                guard let document = document, document.exists,
                      let data = document.data() else {
                    self?.errorMessage = "User data not found"
                    return
                }

                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: data)
                    let user = try JSONDecoder().decode(User.self, from: jsonData)
                    self?.currentUser = user
                    self?.isAuthenticated = true
                } catch {
                    self?.errorMessage = "Failed to decode user data"
                }
            }
        }
    }

    func updateUserProfile(username: String? = nil, profileImage: UIImage? = nil) {
        guard let currentUser = currentUser else { return }

        isLoading = true
        errorMessage = nil

        var updates: [String: Any] = [:]

        if let username = username {
            updates["username"] = username
        }

        if let profileImage = profileImage {
            uploadProfileImage(image: profileImage) { [weak self] imageUrl in
                if let imageUrl = imageUrl {
                    updates["profileImageUrl"] = imageUrl
                    self?.performProfileUpdate(updates: updates)
                } else {
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        self?.errorMessage = "Failed to upload image"
                    }
                }
            }
        } else {
            performProfileUpdate(updates: updates)
        }
    }

    private func uploadProfileImage(image: UIImage, completion: @escaping (String?) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.5) else {
            completion(nil)
            return
        }

        let imageName = "\(currentUser?.id ?? UUID().uuidString)_\(Date().timeIntervalSince1970).jpg"
        let imageRef = storage.reference().child("profile_images/\(imageName)")

        imageRef.putData(imageData, metadata: nil) { _, error in
            if let error = error {
                print("Error uploading image: \(error)")
                completion(nil)
                return
            }

            imageRef.downloadURL { url, error in
                if let error = error {
                    print("Error getting download URL: \(error)")
                    completion(nil)
                    return
                }

                completion(url?.absoluteString)
            }
        }
    }

    private func performProfileUpdate(updates: [String: Any]) {
        guard let currentUser = currentUser else { return }

        db.collection("users").document(currentUser.id).updateData(updates) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false

                if let error = error {
                    self?.errorMessage = error.localizedDescription
                } else {
                    // Update local user data
                    if let username = updates["username"] as? String {
                        self?.currentUser?.username = username
                    }
                    if let imageUrl = updates["profileImageUrl"] as? String {
                        self?.currentUser?.profileImageUrl = imageUrl
                    }
                }
            }
        }
    }

    // MARK: - Error Mapping
    private func mapAuthError(_ error: Error) -> String {
        let nsError = error as NSError
        let code = AuthErrorCode(_bridgedNSError: nsError)
        switch code {
        case .networkError:
            return "Network error. Check your internet connection and try again."
        case .operationNotAllowed:
            return "Email/Password sign-in is disabled. Enable it in Firebase Console."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .emailAlreadyInUse:
            return "This email is already in use. Try signing in instead."
        case .weakPassword:
            return "Password is too weak. Use at least 6 characters."
        case .tooManyRequests:
            return "Too many attempts. Please try again later."
        case .appNotAuthorized:
            return "App not authorized. Check bundle ID and GoogleService-Info.plist."
        case .invalidAPIKey:
            return "Invalid API key. Verify GoogleService-Info.plist is correct."
        default:
            return nsError.localizedDescription
        }
    }
}
