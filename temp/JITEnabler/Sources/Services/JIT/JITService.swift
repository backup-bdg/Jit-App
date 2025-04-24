import Foundation
import UIKit

// MARK: - Main JIT Service
class JITService {
    static let shared = JITService()
    
    // API Client
    private let apiClient = APIClient.shared
    private let sessionManager = SessionManager.shared
    private let keychainHelper = KeychainHelper.shared
    
    // Process and Memory Management
    private let processManager = ProcessManagementService()
    private let memoryManager = MemoryManagementService()
    
    // Configuration
    private let loggingEnabled = true
    private let jitQueue = DispatchQueue(label: "com.jitenabler.jitqueue", qos: .userInitiated)
    
    // Cache to track which apps have JIT enabled
    private var jitEnabledApps: Set<String> = []
    
    private init() {
        // Load cached JIT-enabled apps from UserDefaults
        if let appBundleIDs = UserDefaults.standard.array(forKey: "com.jitenabler.enabledApps") as? [String] {
            jitEnabledApps = Set(appBundleIDs)
        }
    }
}

// MARK: - Authentication and Device Registration
extension JITService {
    /// Check if device is registered with JIT service
    func isDeviceRegistered() -> Bool {
        return keychainHelper.getToken() != nil
    }
    
    /// Register device with JIT service
    func registerDevice(completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let baseURL = sessionManager.backendURL else {
            completion(.failure(JITError.missingBackendURL))
            return
        }
        
        let deviceInfo = DeviceInfo.current()
        
        logMessage("Registering device: \(deviceInfo.deviceModel)")
        
        apiClient.registerDevice(deviceInfo: deviceInfo, baseURL: baseURL) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let token):
                self.keychainHelper.saveToken(token)
                self.logMessage("Device registered successfully")
                
                // Save device info
                self.sessionManager.saveDeviceInfo(deviceInfo)
                
                completion(.success(true))
                
            case .failure(let error):
                self.logMessage("Device registration failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
}

// MARK: - JIT Session Management
extension JITService {
    /// Get all JIT sessions for the device
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
                self.logMessage("Retrieved \(sessions.count) device sessions")
                self.sessionManager.updateSessions(sessions)
                completion(.success(sessions))
                
            case .failure(let error):
                self.logMessage("Failed to retrieve device sessions: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    /// Get status of a specific JIT session
    func getSessionStatus(sessionID: String, completion: @escaping (Result<JITSession, Error>) -> Void) {
        guard let baseURL = sessionManager.backendURL else {
            completion(.failure(JITError.missingBackendURL))
            return
        }
        
        guard let token = keychainHelper.getToken() else {
            completion(.failure(JITError.authenticationFailed))
            return
        }
        
        // First check if we have it cached
        if let session = sessionManager.getSession(id: sessionID) {
            if session.isCompleted || session.isFailed {
                logMessage("Using cached session: \(sessionID)")
                completion(.success(session))
                return
            }
        }
        
        // Otherwise fetch from server
        logMessage("Fetching session status for ID: \(sessionID)")
        
        apiClient.getSessionStatus(sessionID: sessionID, token: token, baseURL: baseURL) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let session):
                self.logMessage("Session status: \(session.status)")
                completion(.success(session))
                
            case .failure(let error):
                self.logMessage("Failed to get session status: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
}

// MARK: - JIT Enablement
extension JITService {
    /// Check if JIT is enabled for a specific app
    func isJITEnabled(for bundleID: String) -> Bool {
        return jitEnabledApps.contains(bundleID)
    }
    
    /// Enable JIT for a specific app
    func enableJIT(for app: AppInfo, completion: @escaping (Result<JITEnablementResponse, Error>) -> Void) {
        guard let baseURL = sessionManager.backendURL else {
            completion(.failure(JITError.missingBackendURL))
            return
        }
        
        guard let token = keychainHelper.getToken() else {
            completion(.failure(JITError.authenticationFailed))
            return
        }
        
        logMessage("Enabling JIT for app: \(app.name) (\(app.bundleID))")
        
        apiClient.enableJIT(bundleID: app.bundleID, token: token, baseURL: baseURL) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let response):
                self.logMessage("JIT enablement initiated successfully")
                completion(.success(response))
                
            case .failure(let error):
                self.logMessage("JIT enablement failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    /// Apply JIT instructions to enable JIT for an app
    func applyJITInstructions(_ instructions: JITInstructions, for app: AppInfo, completion: @escaping (Bool) -> Void) {
        jitQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.logMessage("Starting to apply JIT instructions for \(app.name)")
            
            // Log details for debugging
            self.logMessage("JIT instructions details:")
            self.logMessage("- Set CS_DEBUGGED: \(instructions.setCsDebugged)")
            if let toggleWx = instructions.toggleWxMemory {
                self.logMessage("- Toggle W^X Memory: \(toggleWx)")
            }
            if let regions = instructions.memoryRegions {
                self.logMessage("- Memory Regions: \(regions.count)")
            }
            
            // Launch the app if needed
            if let url = self.getAppURL(for: app.bundleID) {
                let launched = self.processManager.launchApp(bundleID: app.bundleID, appURL: url)
                guard launched else {
                    self.logMessage("Failed to launch app: \(app.bundleID)")
                    DispatchQueue.main.async {
                        completion(false)
                    }
                    return
                }
            } else {
                self.logMessage("App URL not found for: \(app.bundleID)")
            }
            
            // Apply JIT instructions
            let success = self.applyInstructions(instructions, for: app.bundleID)
            
            if success {
                // Mark app as JIT-enabled in cache
                self.jitEnabledApps.insert(app.bundleID)
                
                // Save to UserDefaults
                UserDefaults.standard.set(Array(self.jitEnabledApps), forKey: "com.jitenabler.enabledApps")
                
                self.logMessage("JIT instructions applied successfully for \(app.name)")
            } else {
                self.logMessage("Failed to apply JIT instructions for \(app.name)")
            }
            
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func applyInstructions(_ instructions: JITInstructions, for bundleID: String) -> Bool {
        var success = true
        
        // Step 1: Set CS_DEBUGGED flag if needed
        if instructions.setCsDebugged {
            success = success && setCsDebuggedFlag(for: bundleID)
        }
        
        // Step 2: Toggle W^X memory if needed
        if let toggleWx = instructions.toggleWxMemory, toggleWx {
            success = success && memoryManager.toggleWxMemory(for: bundleID, processManager: processManager)
        }
        
        // Step 3: Modify memory regions if needed
        if let regions = instructions.memoryRegions, !regions.isEmpty {
            success = success && memoryManager.modifyMemoryRegions(regions, for: bundleID, processManager: processManager)
        }
        
        return success
    }
    
    private func setCsDebuggedFlag(for bundleID: String) -> Bool {
        guard let pid = processManager.getProcessID(for: bundleID) else {
            logMessage("Process ID not found for: \(bundleID)")
            return false
        }
        
        // Set CS_DEBUGGED flag
        let result = processManager.setCsopsFlag(pid: pid, flag: 0x10) // CS_DEBUGGED = 0x10
        
        if result {
            logMessage("Successfully set CS_DEBUGGED flag for PID: \(pid)")
            return true
        } else {
            logMessage("Failed to set CS_DEBUGGED flag for PID: \(pid)")
            return false
        }
    }
    
    private func getAppURL(for bundleID: String) -> URL? {
        guard let workspace = NSClassFromString("LSApplicationWorkspace")?.perform(Selector(("defaultWorkspace")))?.takeUnretainedValue() else {
            return nil
        }
        
        guard let appProxy = workspace.perform(
            Selector(("applicationProxyForIdentifier:")),
            with: bundleID
        )?.takeUnretainedValue() else {
            return nil
        }
        
        guard let bundleURL = appProxy.perform(Selector(("bundleURL")))?.takeUnretainedValue() as? URL else {
            return nil
        }
        
        return bundleURL
    }
    
    private func logMessage(_ message: String) {
        if loggingEnabled {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timestamp)] JITService: \(message)")
        }
    }
}

// MARK: - JIT Errors
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
            return "Application not found"
        case .insufficientPermissions:
            return "Insufficient permissions"
        }
    }
}
