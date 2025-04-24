import Foundation

class KeychainHelper {
    static let shared = KeychainHelper()
    
    // Storage keys
    private let tokenKey = "com.jitenabler.jwtToken"
    private let defaults = UserDefaults.standard
    
    // Adds logging capability
    private let loggingEnabled = true
    
    private init() {}
    
    // MARK: - Token Management
    
    func saveToken(_ token: String) {
        defaults.set(token, forKey: tokenKey)
        logMessage("Token saved to UserDefaults")
    }
    
    func getToken() -> String? {
        let token = defaults.string(forKey: tokenKey)
        if token != nil {
            logMessage("Retrieved token from UserDefaults")
        }
        return token
    }
    
    func deleteToken() {
        defaults.removeObject(forKey: tokenKey)
        logMessage("Token deleted from UserDefaults")
    }
    
    // MARK: - Secure Storage Management
    
    func saveSecureData(_ data: Data, forKey key: String) {
        let base64String = data.base64EncodedString()
        defaults.set(base64String, forKey: key)
        logMessage("Secure data saved for key: \(key)")
    }
    
    func getSecureData(forKey key: String) -> Data? {
        guard let base64String = defaults.string(forKey: key),
              let data = Data(base64Encoded: base64String) else {
            return nil
        }
        logMessage("Retrieved secure data for key: \(key)")
        return data
    }
    
    func deleteSecureData(forKey key: String) {
        defaults.removeObject(forKey: key)
        logMessage("Secure data deleted for key: \(key)")
    }
    
    // MARK: - Helper Methods
    
    private func logMessage(_ message: String) {
        if loggingEnabled {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timestamp)] LocalStorage: \(message)")
        }
    }
}