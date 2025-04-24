import Foundation
import UIKit
import MobileCoreServices

class InstalledAppManager {
    static let shared = InstalledAppManager()
    
    // Storage keys
    private let userDefaults = UserDefaults.standard
    private let customAppsKey = "com.jitenabler.customApps"
    private let recentAppsKey = "com.jitenabler.recentApps"
    private let favoriteAppsKey = "com.jitenabler.favoriteApps"
    private let cachedAppsKey = "com.jitenabler.cachedApps"
    private let lastScanTimeKey = "com.jitenabler.lastScanTime"
    
    // App collections
    private(set) var customApps: [AppInfo] = []
    private(set) var recentApps: [AppInfo] = []
    private(set) var favoriteApps: [AppInfo] = []
    private(set) var cachedApps: [AppInfo] = []
    
    // Configuration
    private let maxRecentApps = 15
    private let cacheDuration: TimeInterval = 86400 // 24 hours in seconds
    private let loggingEnabled = true
    
    private init() {
        loadSavedData()
        refreshCachedAppsIfNeeded()
    }
    
    // MARK: - App Management
    
    func addCustomApp(_ app: AppInfo) {
        // Don't add duplicates
        if !customApps.contains(where: { $0.bundleID == app.bundleID }) {
            let newApp = AppInfo(
                id: UUID().uuidString,
                bundleID: app.bundleID,
                name: app.name,
                category: app.category,
                iconName: app.iconName
            )
            customApps.append(newApp)
            saveCustomApps()
            logMessage("Added custom app: \(app.name) (\(app.bundleID))")
        }
    }
    
    func removeCustomApp(_ app: AppInfo) {
        customApps.removeAll { $0.bundleID == app.bundleID }
        saveCustomApps()
        logMessage("Removed custom app: \(app.name) (\(app.bundleID))")
    }
    
    func addRecentApp(_ app: AppInfo) {
        // Remove if already exists
        recentApps.removeAll { $0.bundleID == app.bundleID }
        
        // Add to the beginning of the array
        recentApps.insert(app, at: 0)
        
        // Limit to maxRecentApps
        if recentApps.count > maxRecentApps {
            recentApps = Array(recentApps.prefix(maxRecentApps))
        }
        
        saveRecentApps()
        logMessage("Added app to recent list: \(app.name)")
    }
    
    func clearRecentApps() {
        recentApps.removeAll()
        saveRecentApps()
        logMessage("Cleared recent apps list")
    }
    
    func toggleFavorite(_ app: AppInfo) -> Bool {
        if let index = favoriteApps.firstIndex(where: { $0.bundleID == app.bundleID }) {
            favoriteApps.remove(at: index)
            saveFavoriteApps()
            logMessage("Removed app from favorites: \(app.name)")
            return false
        } else {
            favoriteApps.append(app)
            saveFavoriteApps()
            logMessage("Added app to favorites: \(app.name)")
            return true
        }
    }
    
    func isFavorite(_ app: AppInfo) -> Bool {
        return favoriteApps.contains(where: { $0.bundleID == app.bundleID })
    }
    
    // MARK: - App Scanning and Detection
    
    func scanForApps(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.logMessage("Starting app scan")
            
            // Start with predefined apps
            var scannedApps = AppInfo.allPredefinedApps
            
            // Add system-detected apps when in a real device context
            // (This would use real app detection mechanisms on a non-sandboxed app)
            // For now, we'll just add some simulated app detections
            let simulatedDetectedApps = self.simulateAppDetection()
            scannedApps.append(contentsOf: simulatedDetectedApps)
            
            // Update cache
            self.cachedApps = scannedApps
            self.saveCachedApps()
            
            // Update last scan time
            self.userDefaults.set(Date().timeIntervalSince1970, forKey: self.lastScanTimeKey)
            
            self.logMessage("App scan completed, found \(scannedApps.count) apps")
            
            DispatchQueue.main.async {
                completion(true)
            }
        }
    }
    
    func refreshCachedAppsIfNeeded() {
        // Check if we need to refresh the cache
        let lastScanTime = userDefaults.double(forKey: lastScanTimeKey)
        let currentTime = Date().timeIntervalSince1970
        
        if cachedApps.isEmpty || (currentTime - lastScanTime) > cacheDuration {
            scanForApps { [weak self] success in
                if success {
                    self?.logMessage("Cache refreshed successfully")
                } else {
                    self?.logMessage("Failed to refresh app cache")
                }
            }
        }
    }
    
    // MARK: - App Retrieval
    
    func getApps(for category: AppCategory) -> [AppInfo] {
        // Start with predefined and detected apps for the category
        var categoryApps = cachedApps.filter { $0.category == category }
        
        // Add custom apps for the category
        categoryApps.append(contentsOf: customApps.filter { $0.category == category })
        
        // Remove duplicates (prefer custom apps over predefined/detected)
        var uniqueApps: [AppInfo] = []
        var processedBundleIDs = Set<String>()
        
        for app in categoryApps {
            if !processedBundleIDs.contains(app.bundleID) {
                uniqueApps.append(app)
                processedBundleIDs.insert(app.bundleID)
            }
        }
        
        return uniqueApps
    }
    
    func getAllApps() -> [AppInfo] {
        // Combine cached apps and custom apps
        var allApps = cachedApps
        
        // Add custom apps (overriding cached apps with same bundle ID)
        for customApp in customApps {
            if let index = allApps.firstIndex(where: { $0.bundleID == customApp.bundleID }) {
                allApps[index] = customApp
            } else {
                allApps.append(customApp)
            }
        }
        
        return allApps
    }
    
    func getRecentApps() -> [AppInfo] {
        return recentApps
    }
    
    func getFavoriteApps() -> [AppInfo] {
        return favoriteApps
    }
    
    func findApp(byBundleID bundleID: String) -> AppInfo? {
        // Check custom apps first
        if let app = customApps.first(where: { $0.bundleID == bundleID }) {
            return app
        }
        
        // Then check cached apps
        if let app = cachedApps.first(where: { $0.bundleID == bundleID }) {
            return app
        }
        
        // Finally check predefined apps
        return AppInfo.allPredefinedApps.first(where: { $0.bundleID == bundleID })
    }
    
    // MARK: - Private Methods
    
    private func loadSavedData() {
        loadCustomApps()
        loadRecentApps()
        loadFavoriteApps()
        loadCachedApps()
    }
    
    private func saveCustomApps() {
        if let data = try? JSONEncoder().encode(customApps) {
            userDefaults.set(data, forKey: customAppsKey)
        }
    }
    
    private func loadCustomApps() {
        guard let data = userDefaults.data(forKey: customAppsKey) else { return }
        
        if let loadedApps = try? JSONDecoder().decode([AppInfo].self, from: data) {
            customApps = loadedApps
            logMessage("Loaded \(loadedApps.count) custom apps from storage")
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
            logMessage("Loaded \(loadedApps.count) recent apps from storage")
        }
    }
    
    private func saveFavoriteApps() {
        if let data = try? JSONEncoder().encode(favoriteApps) {
            userDefaults.set(data, forKey: favoriteAppsKey)
        }
    }
    
    private func loadFavoriteApps() {
        guard let data = userDefaults.data(forKey: favoriteAppsKey) else { return }
        
        if let loadedApps = try? JSONDecoder().decode([AppInfo].self, from: data) {
            favoriteApps = loadedApps
            logMessage("Loaded \(loadedApps.count) favorite apps from storage")
        }
    }
    
    private func saveCachedApps() {
        if let data = try? JSONEncoder().encode(cachedApps) {
            userDefaults.set(data, forKey: cachedAppsKey)
        }
    }
    
    private func loadCachedApps() {
        guard let data = userDefaults.data(forKey: cachedAppsKey) else { return }
        
        if let loadedApps = try? JSONDecoder().decode([AppInfo].self, from: data) {
            cachedApps = loadedApps
            logMessage("Loaded \(loadedApps.count) cached apps from storage")
        }
    }
    
    private func simulateAppDetection() -> [AppInfo] {
        // In a real implementation, this would use private APIs to detect installed apps
        // For the purpose of this app, we'll just simulate finding some additional apps
        
        let additionalEmulators = [
            AppInfo(bundleID: "com.retroarch.ra32", name: "RetroArch", category: .emulators),
            AppInfo(bundleID: "org.desmume.desmume", name: "DeSmuME", category: .emulators),
            AppInfo(bundleID: "org.dolphin-emu.dolphin", name: "Dolphin", category: .emulators),
            AppInfo(bundleID: "com.seleuco.mame4ios", name: "MAME4iOS", category: .emulators)
        ]
        
        let additionalJSApps = [
            AppInfo(bundleID: "com.twostraws.javascript", name: "JavaScript Runner", category: .javascriptApps),
            AppInfo(bundleID: "net.sourceforge.v8", name: "V8 Engine", category: .javascriptApps),
            AppInfo(bundleID: "org.nodejs.node", name: "Node.js", category: .javascriptApps)
        ]
        
        let additionalOtherApps = [
            AppInfo(bundleID: "com.virtualbox.virtualbox", name: "VirtualBox", category: .otherApps),
            AppInfo(bundleID: "org.qemu.qemu", name: "QEMU", category: .otherApps),
            AppInfo(bundleID: "com.wine.wine", name: "Wine", category: .otherApps)
        ]
        
        return additionalEmulators + additionalJSApps + additionalOtherApps
    }
    
    // Basic app icon detection (would be expanded in a full implementation)
    func getAppIcon(for bundleID: String) -> UIImage? {
        // In a real implementation, this would fetch the app icon from the installed app
        // For now, return a system icon based on app category
        guard let app = findApp(byBundleID: bundleID) else {
            return UIImage(systemName: "app")
        }
        
        switch app.category {
        case .emulators:
            return UIImage(systemName: "gamecontroller")
        case .javascriptApps:
            return UIImage(systemName: "chevron.left.forwardslash.chevron.right")
        case .otherApps:
            return UIImage(systemName: "app.badge")
        }
    }
    
    private func logMessage(_ message: String) {
        if loggingEnabled {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timestamp)] AppManager: \(message)")
        }
    }
}