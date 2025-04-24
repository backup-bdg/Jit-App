import Foundation

struct AppInfo: Codable, Identifiable, Hashable {
    let id: String
    let bundleID: String
    let name: String
    let category: AppCategory
    let iconName: String?
    
    init(id: String = UUID().uuidString, bundleID: String, name: String, category: AppCategory, iconName: String? = nil) {
        self.id = id
        self.bundleID = bundleID
        self.name = name
        self.category = category
        self.iconName = iconName
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        return lhs.id == rhs.id
    }
}

enum AppCategory: String, Codable, CaseIterable {
    case emulators = "Emulators"
    case javascriptApps = "JavaScript Apps"
    case otherApps = "Other Apps"
    
    var displayName: String {
        return self.rawValue
    }
}

// Predefined app templates
extension AppInfo {
    static let emulators: [AppInfo] = [
        AppInfo(bundleID: "com.rileytestut.Delta", name: "Delta Emulator", category: .emulators),
        AppInfo(bundleID: "org.ppsspp.ppsspp", name: "PPSSPP", category: .emulators),
        AppInfo(bundleID: "com.utmapp.UTM", name: "UTM", category: .emulators),
        AppInfo(bundleID: "net.nerd.iNDS", name: "iNDS", category: .emulators),
        AppInfo(bundleID: "com.provenance-emu.provenance", name: "Provenance", category: .emulators)
    ]
    
    static let javascriptApps: [AppInfo] = [
        AppInfo(bundleID: "com.playjs.playjs", name: "Play.js", category: .javascriptApps),
        AppInfo(bundleID: "com.hamzasood.JSBox", name: "JSBox", category: .javascriptApps),
        AppInfo(bundleID: "com.tinyspeck.chatlyio", name: "Scriptable", category: .javascriptApps)
    ]
    
    static let otherApps: [AppInfo] = [
        AppInfo(bundleID: "com.bluestack.BlueStacks", name: "BlueStacks", category: .otherApps),
        AppInfo(bundleID: "com.parallels.access", name: "Parallels Access", category: .otherApps)
    ]
    
    static let allPredefinedApps: [AppInfo] = emulators + javascriptApps + otherApps
}

// Response models for JIT enablement
struct JITEnablementResponse: Codable {
    let status: String
    let sessionId: String
    let message: String
    let token: String
    let method: String
    let instructions: JITInstructions
    
    enum CodingKeys: String, CodingKey {
        case status
        case sessionId = "session_id"
        case message
        case token
        case method
        case instructions
    }
}

struct JITInstructions: Codable {
    let setCsDebugged: Bool
    let toggleWxMemory: Bool?
    let memoryRegions: [MemoryRegion]?
    
    enum CodingKeys: String, CodingKey {
        case setCsDebugged = "set_cs_debugged"
        case toggleWxMemory = "toggle_wx_memory"
        case memoryRegions = "memory_regions"
    }
}

struct MemoryRegion: Codable {
    let address: String
    let size: String
    let permissions: String
}

struct JITSession: Codable, Identifiable {
    let id: String
    let status: String
    let startedAt: TimeInterval
    let completedAt: TimeInterval?
    let bundleId: String
    let method: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case status
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case bundleId = "bundle_id"
        case method
    }
    
    var startDate: Date {
        return Date(timeIntervalSince1970: startedAt)
    }
    
    var completionDate: Date? {
        guard let completedAt = completedAt else { return nil }
        return Date(timeIntervalSince1970: completedAt)
    }
    
    var isCompleted: Bool {
        return status == "completed"
    }
    
    var isFailed: Bool {
        return status == "failed"
    }
    
    var isProcessing: Bool {
        return status == "processing"
    }
}