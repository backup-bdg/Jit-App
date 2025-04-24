import Foundation

class KeychainHelper {
    static let shared = KeychainHelper()
    
    private let tokenKey = "com.jitenabler.jwtToken"
    private let defaults = UserDefaults.standard
    
    private init() {}
    
    // MARK: - Token Management
    
    func saveToken(_ token: String) {
        defaults.set(token, forKey: tokenKey)
    }
    
    func getToken() -> String? {
        return defaults.string(forKey: tokenKey)
    }
    
    func deleteToken() {
        defaults.removeObject(forKey: tokenKey)
    }
}