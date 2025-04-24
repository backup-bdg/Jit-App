import Foundation
import UIKit

class JITService {
    static let shared = JITService()
    
    private let apiClient = APIClient.shared
    private let sessionManager = SessionManager.shared
    private let keychainHelper = KeychainHelper.shared
    
    private init() {}
    
    // MARK: - Public Methods
    
    func registerDevice(completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let baseURL = sessionManager.backendURL else {
            completion(.failure(JITError.missingBackendURL))
            return
        }
        
        let deviceInfo = DeviceInfo.current()
        
        apiClient.registerDevice(deviceInfo: deviceInfo, baseURL: baseURL) { [weak self] result in
            switch result {
            case .success(let token):
                // Save the token to keychain
                self?.keychainHelper.saveToken(token)
                
                // Save device info
                self?.sessionManager.saveDeviceInfo(deviceInfo)
                
                completion(.success(true))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func enableJIT(for app: AppInfo, completion: @escaping (Result<JITEnablementResponse, Error>) -> Void) {
        guard let baseURL = sessionManager.backendURL else {
            completion(.failure(JITError.missingBackendURL))
            return
        }
        
        guard let token = keychainHelper.getToken() else {
            // If no token, try to register the device first
            registerDevice { [weak self] result in
                switch result {
                case .success:
                    // Now that we have a token, try enabling JIT again
                    guard let token = self?.keychainHelper.getToken() else {
                        completion(.failure(JITError.authenticationFailed))
                        return
                    }
                    
                    self?.apiClient.enableJIT(bundleID: app.bundleID, token: token, baseURL: baseURL, completion: completion)
                    
                case .failure(let error):
                    completion(.failure(error))
                }
            }
            return
        }
        
        // We have a token, proceed with JIT enablement
        apiClient.enableJIT(bundleID: app.bundleID, token: token, baseURL: baseURL) { [weak self] result in
            switch result {
            case .success(let response):
                // Save the session for history
                self?.sessionManager.addSession(
                    JITSession(
                        id: response.sessionId,
                        status: "completed",
                        startedAt: Date().timeIntervalSince1970,
                        completedAt: Date().timeIntervalSince1970,
                        bundleId: app.bundleID,
                        method: response.method
                    )
                )
                
                completion(.success(response))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func getSessionStatus(sessionID: String, completion: @escaping (Result<JITSession, Error>) -> Void) {
        guard let baseURL = sessionManager.backendURL else {
            completion(.failure(JITError.missingBackendURL))
            return
        }
        
        guard let token = keychainHelper.getToken() else {
            completion(.failure(JITError.authenticationFailed))
            return
        }
        
        apiClient.getSessionStatus(sessionID: sessionID, token: token, baseURL: baseURL, completion: completion)
    }
    
    func getDeviceSessions(completion: @escaping (Result<[JITSession], Error>) -> Void) {
        guard let baseURL = sessionManager.backendURL else {
            completion(.failure(JITError.missingBackendURL))
            return
        }
        
        guard let token = keychainHelper.getToken() else {
            completion(.failure(JITError.authenticationFailed))
            return
        }
        
        apiClient.getDeviceSessions(token: token, baseURL: baseURL) { [weak self] result in
            switch result {
            case .success(let sessions):
                // Update local session cache
                self?.sessionManager.updateSessions(sessions)
                completion(.success(sessions))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func isDeviceRegistered() -> Bool {
        return keychainHelper.getToken() != nil
    }
    
    func applyJITInstructions(_ instructions: JITInstructions, completion: @escaping (Bool) -> Void) {
        // In a real implementation, this would use private APIs to apply the JIT instructions
        // Since we can't include that code here, we'll simulate success
        
        // Log the instructions for debugging
        print("Applying JIT instructions:")
        print("- Set CS_DEBUGGED: \(instructions.setCsDebugged)")
        if let toggleWx = instructions.toggleWxMemory {
            print("- Toggle W^X Memory: \(toggleWx)")
        }
        if let memoryRegions = instructions.memoryRegions {
            print("- Memory Regions: \(memoryRegions.count)")
            for (index, region) in memoryRegions.enumerated() {
                print("  Region \(index): \(region.address) (size: \(region.size), permissions: \(region.permissions))")
            }
        }
        
        // Simulate a delay for the JIT enablement process
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            // Simulate success
            DispatchQueue.main.async {
                completion(true)
            }
        }
    }
}

// MARK: - Error Types

enum JITError: Error, LocalizedError {
    case missingBackendURL
    case authenticationFailed
    case jitEnablementFailed
    case sessionNotFound
    
    var errorDescription: String? {
        switch self {
        case .missingBackendURL:
            return "Backend URL not configured"
        case .authenticationFailed:
            return "Authentication failed"
        case .jitEnablementFailed:
            return "Failed to enable JIT"
        case .sessionNotFound:
            return "JIT session not found"
        }
    }
}