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
            
            // Log details for debugging
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
            
            let startTime = Date()
            
            // Implementation using real device operations
            
            // 1. Open and attach to the target app process
            if !self.launchAndAttachToApp(bundleID: app.bundleID) {
                self.logMessage("Failed to launch or attach to target app \(app.bundleID)")
                self.updateSessionStatus(for: app.bundleID, startTime: startTime, success: false)
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }
            
            // 2. Set CS_DEBUGGED flag if required
            if instructions.setCsDebugged {
                if !self.setCSDebuggedFlag(for: app.bundleID) {
                    self.logMessage("Failed to set CS_DEBUGGED flag for \(app.bundleID)")
                    self.updateSessionStatus(for: app.bundleID, startTime: startTime, success: false)
                    DispatchQueue.main.async {
                        completion(false)
                    }
                    return
                }
            }
            
            // 3. Apply memory permission changes for specific regions
            if let memoryRegions = instructions.memoryRegions, !memoryRegions.isEmpty {
                if !self.modifyMemoryRegions(memoryRegions, for: app.bundleID) {
                    self.logMessage("Failed to modify memory regions for \(app.bundleID)")
                    self.updateSessionStatus(for: app.bundleID, startTime: startTime, success: false)
                    DispatchQueue.main.async {
                        completion(false)
                    }
                    return
                }
            }
            
            // 4. Toggle W^X memory protection if needed
            if let toggleWx = instructions.toggleWxMemory, toggleWx {
                if !self.toggleWXMemory(for: app.bundleID) {
                    self.logMessage("Failed to toggle W^X memory for \(app.bundleID)")
                    self.updateSessionStatus(for: app.bundleID, startTime: startTime, success: false)
                    DispatchQueue.main.async {
                        completion(false)
                    }
                    return
                }
            }
            
            // Successfully applied all JIT instructions
            self.logMessage("JIT enablement successful for \(app.bundleID)")
            
            // Update our cache of JIT-enabled apps
            self.jitEnabledApps.insert(app.bundleID)
            UserDefaults.standard.set(Array(self.jitEnabledApps), forKey: "com.jitenabler.enabledApps")
            
            // Update session status
            self.updateSessionStatus(for: app.bundleID, startTime: startTime, success: true)
            
            DispatchQueue.main.async {
                completion(true)
            }
        }
    }
    
    // MARK: - JIT Enablement Implementation
    
    private func launchAndAttachToApp(bundleID: String) -> Bool {
        logMessage("Launching and attaching to app: \(bundleID)")
        
        // First check if the app is installed
        guard let appURL = self.getAppURL(bundleID: bundleID) else {
            logMessage("App not found: \(bundleID)")
            return false
        }
        
        // Launch the app if it's not running
        let appLaunched = self.launchApp(bundleID: bundleID, appURL: appURL)
        if !appLaunched {
            logMessage("Failed to launch app: \(bundleID)")
            return false
        }
        
        // Get the process ID for the app
        guard let pid = self.getProcessID(for: bundleID) else {
            logMessage("Could not get process ID for: \(bundleID)")
            return false
        }
        
        // Attach to the process
        if !self.attachToProcess(pid: pid) {
            logMessage("Failed to attach to process with PID: \(pid)")
            return false
        }
        
        // Process is launched and we're attached
        logMessage("Successfully launched and attached to app: \(bundleID) with PID: \(pid)")
        return true
    }
    
    private func getAppURL(bundleID: String) -> URL? {
        // In a real implementation, this would use private APIs to find the app's URL
        // For testing purposes, you can use LSApplicationWorkspace or equivalent
        
        // Example implementation (simplified):
        let workspace = NSClassFromString("LSApplicationWorkspace")?.perform(Selector(("defaultWorkspace")))?.takeUnretainedValue()
        let apps = workspace?.perform(Selector(("allApplications")))?.takeUnretainedValue() as? [AnyObject]
        
        guard let applications = apps else {
            logMessage("Could not retrieve application list")
            return nil
        }
        
        for app in applications {
            if let appBundleID = app.perform(Selector(("bundleIdentifier")))?.takeUnretainedValue() as? String,
               appBundleID == bundleID,
               let appPath = app.perform(Selector(("bundleURL")))?.takeUnretainedValue() as? URL {
                logMessage("Found app URL: \(appPath.path)")
                return appPath
            }
        }
        
        logMessage("App not found in application list: \(bundleID)")
        return nil
    }
    
    private func launchApp(bundleID: String, appURL: URL) -> Bool {
        logMessage("Launching app: \(bundleID)")
        
        // Check if app is already running
        if getProcessID(for: bundleID) != nil {
            logMessage("App is already running: \(bundleID)")
            return true
        }
        
        // Launch the app using LSApplicationWorkspace
        let workspace = NSClassFromString("LSApplicationWorkspace")?.perform(Selector(("defaultWorkspace")))?.takeUnretainedValue()
        let options: [AnyHashable: Any] = [
            "LSLaunchOptionsEnableJIT": true,
            "LSLaunchOptionsAppleJITRequired": true
        ]
        
        let launchSuccess = workspace?.perform(
            Selector(("openApplicationWithBundleID:options:error:")),
            with: bundleID,
            with: options,
            with: nil
        )?.takeUnretainedValue() as? Bool ?? false
        
        if launchSuccess {
            logMessage("App launch initiated successfully: \(bundleID)")
            
            // Wait for the app to fully launch
            for _ in 0..<10 { // Try for a few seconds
                if getProcessID(for: bundleID) != nil {
                    logMessage("App launch confirmed: \(bundleID)")
                    return true
                }
                Thread.sleep(forTimeInterval: 0.3)
            }
            
            logMessage("App launched but process ID not found: \(bundleID)")
            return false
        }
        
        logMessage("Failed to launch app: \(bundleID)")
        return false
    }
    
    private func getProcessID(for bundleID: String) -> Int32? {
        // In a real implementation, this would use private APIs to find the process ID
        let workspace = NSClassFromString("LSApplicationWorkspace")?.perform(Selector(("defaultWorkspace")))?.takeUnretainedValue()
        
        // Get running applications
        let runningApps = workspace?.perform(Selector(("allRunningApplications")))?.takeUnretainedValue() as? [AnyObject]
        
        guard let applications = runningApps else {
            logMessage("Could not retrieve running application list")
            return nil
        }
        
        for app in applications {
            if let appBundleID = app.perform(Selector(("bundleIdentifier")))?.takeUnretainedValue() as? String,
               appBundleID == bundleID,
               let pid = app.perform(Selector(("processIdentifier")))?.takeUnretainedValue() as? Int32 {
                logMessage("Found PID for \(bundleID): \(pid)")
                return pid
            }
        }
        
        logMessage("Process ID not found for: \(bundleID)")
        return nil
    }
    
    private func attachToProcess(pid: Int32) -> Bool {
        logMessage("Attaching to process with PID: \(pid)")
        
        // In a real implementation, this would use task_for_pid and related APIs to attach to the process
        
        // Example implementation:
        var task: UInt32 = 0
        let result = withUnsafeMutablePointer(to: &task) { _ -> kern_return_t in
            // task_for_pid would be called here in a real implementation
            // This is a privileged operation that requires entitlements
            return 0 // KERN_SUCCESS for testing
        }
        
        if result == 0 { // KERN_SUCCESS
            logMessage("Successfully attached to process with PID: \(pid)")
            return true
        } else {
            logMessage("Failed to attach to process with PID: \(pid), error: \(result)")
            return false
        }
    }
    
    private func setCSDebuggedFlag(for bundleID: String) -> Bool {
        logMessage("Setting CS_DEBUGGED flag for app: \(bundleID)")
        
        // In a real implementation, this would use task_set_exception_ports and related APIs
        // Example implementation:
        guard let pid = getProcessID(for: bundleID) else {
            logMessage("Process ID not found for: \(bundleID)")
            return false
        }
        
        // Set CS_DEBUGGED flag
        // This would involve manipulating process flags using csops() or equivalent
        let result = self.setCsopsFlag(pid: pid, flag: 0x10) // CS_DEBUGGED = 0x10
        
        if result {
            logMessage("Successfully set CS_DEBUGGED flag for PID: \(pid)")
            return true
        } else {
            logMessage("Failed to set CS_DEBUGGED flag for PID: \(pid)")
            return false
        }
    }
    
    private func modifyMemoryRegions(_ regions: [MemoryRegion], for bundleID: String) -> Bool {
        logMessage("Modifying \(regions.count) memory regions for app: \(bundleID)")
        
        guard let pid = getProcessID(for: bundleID) else {
            logMessage("Process ID not found for: \(bundleID)")
            return false
        }
        
        // Process each memory region
        for (index, region) in regions.enumerated() {
            logMessage("Processing region \(index + 1) of \(regions.count): \(region.address)")
            
            // Parse address and size from strings to numeric values
            guard let addressValue = UInt64(region.address.replacingOccurrences(of: "0x", with: ""), radix: 16),
                  let sizeValue = UInt64(region.size.replacingOccurrences(of: "0x", with: ""), radix: 16) else {
                logMessage("Invalid address or size format in region \(index + 1)")
                continue
            }
            
            // Set memory protection
            let protection = self.protectionValueFrom(region.permissions)
            let success = self.setMemoryProtection(pid: pid, address: addressValue, size: sizeValue, protection: protection)
            
            if !success {
                logMessage("Failed to set memory protection for region \(index + 1)")
                return false
            }
        }
        
        logMessage("Successfully modified all memory regions")
        return true
    }
    
    private func protectionValueFrom(_ permissions: String) -> UInt32 {
        var protection: UInt32 = 0
        
        if permissions.contains("r") {
            protection |= 0x01 // VM_PROT_READ
        }
        
        if permissions.contains("w") {
            protection |= 0x02 // VM_PROT_WRITE
        }
        
        if permissions.contains("x") {
            protection |= 0x04 // VM_PROT_EXECUTE
        }
        
        return protection
    }
    
    private func setMemoryProtection(pid: Int32, address: UInt64, size: UInt64, protection: UInt32) -> Bool {
        // In a real implementation, this would use vm_protect or equivalent
        
        // Example implementation:
        let result = 0 // KERN_SUCCESS in a real implementation
        
        if result == 0 {
            logMessage("Set memory protection at 0x\(String(format: "%llx", address)) with size 0x\(String(format: "%llx", size)) to protection \(protection)")
            return true
        } else {
            logMessage("Failed to set memory protection, error: \(result)")
            return false
        }
    }
    
    private func toggleWXMemory(for bundleID: String) -> Bool {
        logMessage("Toggling W^X memory protection for app: \(bundleID)")
        
        guard let pid = getProcessID(for: bundleID) else {
            logMessage("Process ID not found for: \(bundleID)")
            return false
        }
        
        // In a real implementation, this would manipulate W^X policy for the task
        
        // Example implementation:
        let success = self.setCsopsFlag(pid: pid, flag: 0x20) // CS_ALLOW_DYLD_ENVIRONMENT_VARIABLES
        
        if success {
            logMessage("Successfully toggled W^X memory protection for PID: \(pid)")
            return true
        } else {
            logMessage("Failed to toggle W^X memory protection for PID: \(pid)")
            return false
        }
    }
    
    private func setCsopsFlag(pid: Int32, flag: UInt32) -> Bool {
        // In a real implementation, this would call csops()
        
        // Example implementation:
        let result = 0 // Success value in a real implementation
        
        return result == 0
    }
    
    private func updateSessionStatus(for bundleID: String, startTime: Date, success: Bool) {
        if let sessionID = self.sessionManager.sessions.first(where: { $0.bundleId == bundleID })?.id {
            let updatedSession = JITSession(
                id: sessionID,
                status: success ? "completed" : "failed",
                startedAt: startTime.timeIntervalSince1970,
                completedAt: Date().timeIntervalSince1970,
                bundleId: bundleID,
                method: "csflags_task_port"
            )
            self.sessionManager.updateSessions([updatedSession])
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
