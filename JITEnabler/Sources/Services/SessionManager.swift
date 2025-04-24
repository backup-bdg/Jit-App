import Foundation

class SessionManager {
    static let shared = SessionManager()
    
    private let userDefaults = UserDefaults.standard
    private let sessionsKey = "com.jitenabler.sessions"
    private let deviceInfoKey = "com.jitenabler.deviceInfo"
    private let backendURLKey = "com.jitenabler.backendURL"
    
    private(set) var sessions: [JITSession] = []
    private(set) var deviceInfo: DeviceInfo?
    
    var backendURL: String? {
        get {
            return userDefaults.string(forKey: backendURLKey)
        }
        set {
            userDefaults.set(newValue, forKey: backendURLKey)
        }
    }
    
    private init() {
        loadSessions()
        loadDeviceInfo()
        
        // Set default backend URL if not set
        if backendURL == nil {
            backendURL = "https://jit-backend-dna8.onrender.com"
        }
    }
    
    // MARK: - Session Management
    
    func addSession(_ session: JITSession) {
        // Add to the beginning of the array for chronological order (newest first)
        sessions.insert(session, at: 0)
        saveSessions()
    }
    
    func updateSessions(_ newSessions: [JITSession]) {
        // Replace existing sessions with the same ID
        var updatedSessions = sessions
        
        for newSession in newSessions {
            if let index = updatedSessions.firstIndex(where: { $0.id == newSession.id }) {
                updatedSessions[index] = newSession
            } else {
                updatedSessions.insert(newSession, at: 0)
            }
        }
        
        sessions = updatedSessions
        saveSessions()
    }
    
    func getSession(id: String) -> JITSession? {
        return sessions.first { $0.id == id }
    }
    
    func clearSessions() {
        sessions.removeAll()
        saveSessions()
    }
    
    // MARK: - Device Info Management
    
    func saveDeviceInfo(_ info: DeviceInfo) {
        deviceInfo = info
        
        if let data = try? JSONEncoder().encode(info) {
            userDefaults.set(data, forKey: deviceInfoKey)
        }
    }
    
    // MARK: - Private Methods
    
    private func saveSessions() {
        if let data = try? JSONEncoder().encode(sessions) {
            userDefaults.set(data, forKey: sessionsKey)
        }
    }
    
    private func loadSessions() {
        guard let data = userDefaults.data(forKey: sessionsKey) else { return }
        
        if let loadedSessions = try? JSONDecoder().decode([JITSession].self, from: data) {
            sessions = loadedSessions
        }
    }
    
    private func loadDeviceInfo() {
        guard let data = userDefaults.data(forKey: deviceInfoKey) else { return }
        
        if let loadedInfo = try? JSONDecoder().decode(DeviceInfo.self, from: data) {
            deviceInfo = loadedInfo
        }
    }
}