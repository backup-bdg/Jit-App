import Foundation
import UIKit

class InstalledAppManager {
    static let shared = InstalledAppManager()
    
    private let userDefaults = UserDefaults.standard
    private let customAppsKey = "com.jitenabler.customApps"
    private let recentAppsKey = "com.jitenabler.recentApps"
    
    private(set) var customApps: [AppInfo] = []
    private(set) var recentApps: [AppInfo] = []
    
    private init() {
        loadCustomApps()
        loadRecentApps()
    }
    
    // MARK: - App Management
    
    func addCustomApp(_ app: AppInfo) {
        // Don't add duplicates
        if !customApps.contains(where: { $0.bundleID == app.bundleID }) {
            customApps.append(app)
            saveCustomApps()
        }
    }
    
    func removeCustomApp(_ app: AppInfo) {
        customApps.removeAll { $0.bundleID == app.bundleID }
        saveCustomApps()
    }
    
    func addRecentApp(_ app: AppInfo) {
        // Remove if already exists
        recentApps.removeAll { $0.bundleID == app.bundleID }
        
        // Add to the beginning of the array
        recentApps.insert(app, at: 0)
        
        // Limit to 10 recent apps
        if recentApps.count > 10 {
            recentApps = Array(recentApps.prefix(10))
        }
        
        saveRecentApps()
    }
    
    func clearRecentApps() {
        recentApps.removeAll()
        saveRecentApps()
    }
    
    // MARK: - App Retrieval
    
    func getApps(for category: AppCategory) -> [AppInfo] {
        switch category {
        case .emulators:
            return AppInfo.emulators + customApps.filter { $0.category == .emulators }
        case .javascriptApps:
            return AppInfo.javascriptApps + customApps.filter { $0.category == .javascriptApps }
        case .otherApps:
            return AppInfo.otherApps + customApps.filter { $0.category == .otherApps }
        }
    }
    
    func getAllApps() -> [AppInfo] {
        return AppInfo.allPredefinedApps + customApps
    }
    
    func getRecentApps() -> [AppInfo] {
        return recentApps
    }
    
    // MARK: - Private Methods
    
    private func saveCustomApps() {
        if let data = try? JSONEncoder().encode(customApps) {
            userDefaults.set(data, forKey: customAppsKey)
        }
    }
    
    private func loadCustomApps() {
        guard let data = userDefaults.data(forKey: customAppsKey) else { return }
        
        if let loadedApps = try? JSONDecoder().decode([AppInfo].self, from: data) {
            customApps = loadedApps
        }
    }
    
    private func saveRecentApps() {
        if let data = try? JSONEncoder().encode(recentApps) {
            userDefaults.set(data, forKey: recentAppsKey)
        }
    }
    
    private func loadRecentApps() {
        guard let data = userDefaults.data(forKey: recentAppsKey) else { return }
        
        if let loadedApps = try? JSONDecoder().decode([AppInfo].self, from: data) {
            recentApps = loadedApps
        }
    }
}