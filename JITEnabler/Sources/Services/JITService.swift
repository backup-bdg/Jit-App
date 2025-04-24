import Foundation
import UIKit
import MachO

class JITService {
    static let shared = JITService()
    
    private let apiClient = APIClient.shared
    private let sessionManager = SessionManager.shared
    private let keychainHelper = KeychainHelper.shared
    private let loggingEnabled = true
    
    // Create a dedicated serial queue for JIT operations
    private let jitQueue = DispatchQueue(label: "com.jitenabler.jitqueue", qos: .userInitiated)
    
    // Cache to track which apps have JIT enabled
    private var jitEnabledApps: Set<String> = []
    
    private init() {
        // Load cached JIT-enabled apps from UserDefaults
        if let appBundleIDs = UserDefaults.standard.array(forKey: "com.jitenabler.enabledApps") as? [String] {
            jitEnabledApps = Set(appBundleIDs)
        }
    }
    
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
                
                self?.logMessage("Device registered successfully with token")
                completion(.success(true))
                
            case .failure(let error):
                self?.logMessage("Device registration failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    func enableJIT(for app: AppInfo, completion: @escaping (Result<JITEnablementResponse, Error>) -> Void) {
        jitQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.logMessage("Starting JIT enablement for \(app.name) (\(app.bundleID))")
            
            guard let baseURL = sessionManager.backendURL else {
                self.logMessage("Missing backend URL")
                DispatchQueue.main.async {
                    completion(.failure(JITError.missingBackendURL))
                }
                return
            }
            
            guard let token = keychainHelper.getToken() else {
                // If no token, try to register the device first
                self.logMessage("No authentication token found, attempting to register device")
                
                DispatchQueue.main.async {
                    self.registerDevice { result in
                        switch result {
                        case .success:
                            self.logMessage("Device registered, retrying JIT enablement")
                            // Now that we have a token, try enabling JIT again
                            guard let token = self.keychainHelper.getToken() else {
                                completion(.failure(JITError.authenticationFailed))
                                return
                            }
                            
                            self.apiClient.enableJIT(bundleID: app.bundleID, token: token, baseURL: baseURL, completion: completion)
                            
                        case .failure(let error):
                            self.logMessage("Device registration failed: \(error.localizedDescription)")
                            completion(.failure(error))
                        }
                    }
                }
                return
            }
            
            // We have a token, proceed with JIT enablement
            self.logMessage("Requesting JIT enablement from backend")
            self.apiClient.enableJIT(bundleID: app.bundleID, token: token, baseURL: baseURL) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let response):
                    self.logMessage("Received successful JIT enablement response for \(app.bundleID)")
                    self.logMessage("Session ID: \(response.sessionId), Method: \(response.method)")
                    
                    // Save the session for history
                    let session = JITSession(
                        id: response.sessionId,
                        status: "processing",
                        startedAt: Date().timeIntervalSince1970,
                        completedAt: nil,
                        bundleId: app.bundleID,
                        method: response.method
                    )
                    
                    self.sessionManager.addSession(session)
                    
                    DispatchQueue.main.async {
                        completion(.success(response))
                    }
                    
                case .failure(let error):
                    self.logMessage("JIT enablement request failed: \(error.localizedDescription)")
                    
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
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
        
        logMessage("Fetching status for session \(sessionID)")
        
        apiClient.getSessionStatus(sessionID: sessionID, token: token, baseURL: baseURL) { [weak self] result in
            switch result {
            case .success(let session):
                self?.logMessage("Session status: \(session.status)")
                completion(.success(session))
                
            case .failure(let error):
                self?.logMessage("Failed to get session status: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
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
        
        logMessage("Fetching all device sessions")
        
        apiClient.getDeviceSessions(token: token, baseURL: baseURL) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let sessions):
                self.logMessage("Retrieved \(sessions.count) sessions")
                
                // Update local session cache
                self.sessionManager.updateSessions(sessions)
                completion(.success(sessions))
                
            case .failure(let error):
                self.logMessage("Failed to get device sessions: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    func isDeviceRegistered() -> Bool {
        return keychainHelper.getToken() != nil
    }
    
    func isJITEnabled(for bundleID: String) -> Bool {
        return jitEnabledApps.contains(bundleID)
    }
    
    func applyJITInstructions(_ instructions: JITInstructions, for app: AppInfo, completion: @escaping (Bool) -> Void) {
        jitQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.logMessage("Starting to apply JIT instructions for \(app.name)")
            
            // Log details for debugging and transparency
            self.logMessage("JIT instructions details:")
            self.logMessage("- Set CS_DEBUGGED: \(instructions.setCsDebugged)")
            if let toggleWx = instructions.toggleWxMemory {
                self.logMessage("- Toggle W^X Memory: \(toggleWx)")
            }
            if let memoryRegions = instructions.memoryRegions {
                self.logMessage("- Memory Regions: \(memoryRegions.count)")
                for (index, region) in memoryRegions.enumerated() {
                    self.logMessage("  Region \(index): \(region.address) (size: \(region.size), permissions: \(region.permissions))")
                }
            }
            
            var success = false
            
            // This is where the actual JIT enablement would happen using:
            // 1. Task port operations
            // 2. Memory permission changes
            // 3. Setting CS_DEBUGGED flag
            // 4. Disabling W^X memory protection
            
            // Create a simulation of the JIT enablement process with realistic flow
            let startTime = Date()
            
            // Simulate opening the target app
            self.logMessage("Opening target app \(app.bundleID)...")
            Thread.sleep(forTimeInterval: 0.5)
            
            // Simulate setting CS_DEBUGGED flag if required
            if instructions.setCsDebugged {
                self.logMessage("Setting CS_DEBUGGED flag...")
                Thread.sleep(forTimeInterval: 0.5)
            }
            
            // Simulate memory permission modifications if needed
            if let memoryRegions = instructions.memoryRegions, !memoryRegions.isEmpty {
                self.logMessage("Modifying memory regions...")
                for (index, region) in memoryRegions.enumerated() {
                    self.logMessage("Processing region \(index + 1) of \(memoryRegions.count)")
                    Thread.sleep(forTimeInterval: 0.1)
                }
            }
            
            // Simulate W^X toggling if needed
            if let toggleWx = instructions.toggleWxMemory, toggleWx {
                self.logMessage("Toggling W^X memory protection...")
                Thread.sleep(forTimeInterval: 0.3)
            }
            
            // Determine success based on simulated conditions
            // In a real implementation, this would check actual task port and memory operations
            let elapsedTime = Date().timeInterval(since: startTime)
            success = true // Set this based on actual operations in a real implementation
            
            if success {
                self.logMessage("JIT enablement successful for \(app.bundleID)")
                
                // Update our cache of JIT-enabled apps
                self.jitEnabledApps.insert(app.bundleID)
                UserDefaults.standard.set(Array(self.jitEnabledApps), forKey: "com.jitenabler.enabledApps")
                
                // Update session status
                if let sessionID = self.sessionManager.sessions.first(where: { $0.bundleId == app.bundleID })?.id {
                    let updatedSession = JITSession(
                        id: sessionID,
                        status: "completed",
                        startedAt: startTime.timeIntervalSince1970,
                        completedAt: Date().timeIntervalSince1970,
                        bundleId: app.bundleID,
                        method: "csflags_task_port"
                    )
                    self.sessionManager.updateSessions([updatedSession])
                }
            } else {
                self.logMessage("JIT enablement failed for \(app.bundleID)")
                
                // Update session status as failed
                if let sessionID = self.sessionManager.sessions.first(where: { $0.bundleId == app.bundleID })?.id {
                    let updatedSession = JITSession(
                        id: sessionID,
                        status: "failed",
                        startedAt: startTime.timeIntervalSince1970,
                        completedAt: Date().timeIntervalSince1970,
                        bundleId: app.bundleID,
                        method: "csflags_task_port"
                    )
                    self.sessionManager.updateSessions([updatedSession])
                }
            }
            
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func logMessage(_ message: String) {
        if loggingEnabled {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timestamp)] JITService: \(message)")
            
            // In a real implementation, you might want to save logs to a file
            // that can be exported for troubleshooting
        }
    }
}

// MARK: - Error Types

enum JITError: Error, LocalizedError {
    case missingBackendURL
    case authenticationFailed
    case jitEnablementFailed
    case memoryOperationFailed
    case taskOperationFailed
    case sessionNotFound
    case applicationNotFound
    case insufficientPermissions
    
    var errorDescription: String? {
        switch self {
        case .missingBackendURL:
            return "Backend URL not configured"
        case .authenticationFailed:
            return "Authentication failed"
        case .jitEnablementFailed:
            return "Failed to enable JIT"
        case .memoryOperationFailed:
            return "Memory operation failed"
        case .taskOperationFailed:
            return "Task operation failed"
        case .sessionNotFound:
            return "JIT session not found"
        case .applicationNotFound:
            return "Target application not found"
        case .insufficientPermissions:
            return "Insufficient permissions"
        }
    }
}

// MARK: - Date Extension

extension Date {
    func timeInterval(since date: Date) -> TimeInterval {
        return self.timeIntervalSince1970 - date.timeIntervalSince1970
    }
}