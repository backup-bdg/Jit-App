import Foundation

// MARK: - Refactored APIClient
class APIClient {
    static let shared = APIClient()
    
    // Services
    private let deviceRegistrationService: DeviceRegistrationService
    private let jitEnablementService: JITEnablementService
    private let sessionManagementService: SessionManagementService
    private let loggingEnabled: Bool
    
    private init() {
        self.deviceRegistrationService = DeviceRegistrationService()
        self.jitEnablementService = JITEnablementService()
        self.sessionManagementService = SessionManagementService()
        self.loggingEnabled = true
    }
    
    // MARK: - Device Registration
    
    func registerDevice(deviceInfo: DeviceInfo, baseURL: String, completion: @escaping (Result<String, Error>) -> Void) {
        logMessage("Delegating device registration")
        deviceRegistrationService.registerDevice(
            deviceInfo: deviceInfo,
            baseURL: baseURL,
            completion: completion
        )
    }
    
    // MARK: - JIT Enablement
    
    func enableJIT(bundleID: String, token: String, baseURL: String, completion: @escaping (Result<JITEnablementResponse, Error>) -> Void) {
        logMessage("Delegating JIT enablement for \(bundleID)")
        
        // Get app information
        let deviceInfo = DeviceInfo.current()
        let appName = getAppName(bundleID: bundleID) ?? bundleID.components(separatedBy: ".").last ?? "App"
        
        jitEnablementService.enableJIT(
            bundleID: bundleID,
            appName: appName,
            deviceInfo: deviceInfo,
            token: token,
            baseURL: baseURL,
            completion: completion
        )
    }
    
    func getSessionStatus(sessionID: String, token: String, baseURL: String, completion: @escaping (Result<JITSession, Error>) -> Void) {
        logMessage("Delegating session status check for \(sessionID)")
        jitEnablementService.getSessionStatus(
            sessionID: sessionID,
            token: token,
            baseURL: baseURL,
            completion: completion
        )
    }
    
    // MARK: - Session Management
    
    func getDeviceSessions(token: String, baseURL: String, completion: @escaping (Result<[JITSession], Error>) -> Void) {
        logMessage("Delegating device sessions retrieval")
        sessionManagementService.getDeviceSessions(
            token: token,
            baseURL: baseURL,
            completion: completion
        )
    }
    
    func cancelSession(sessionID: String, token: String, baseURL: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        logMessage("Delegating session cancellation for \(sessionID)")
        sessionManagementService.cancelSession(
            sessionID: sessionID,
            token: token,
            baseURL: baseURL,
            completion: completion
        )
    }
    
    // MARK: - Helper Methods
    
    private func getAppName(bundleID: String) -> String? {
        // Helper method to get app name using LSApplicationWorkspace
        guard let workspace = NSClassFromString("LSApplicationWorkspace")?.perform(Selector(("defaultWorkspace")))?.takeUnretainedValue() else {
            return nil
        }
        
        guard let appProxy = workspace.perform(
            Selector(("applicationProxyForIdentifier:")),
            with: bundleID
        )?.takeUnretainedValue() else {
            return nil
        }
        
        return appProxy.perform(Selector(("localizedName")))?.takeUnretainedValue() as? String
    }
    
    private func logMessage(_ message: String) {
        if loggingEnabled {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timestamp)] APIClient: \(message)")
        }
    }
}
