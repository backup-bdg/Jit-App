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
            
            // Use real app detection to find installed apps
            let detectedApps = self.detectInstalledApps()
            
            // Update cache
            self.cachedApps = detectedApps
            self.saveCachedApps()
            
            // Update last scan time
            self.userDefaults.set(Date().timeIntervalSince1970, forKey: self.lastScanTimeKey)
            
            self.logMessage("App scan completed, found \(detectedApps.count) apps")
            
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
        
        for app in categoryApps where !processedBundleIDs.contains(app.bundleID) {
            uniqueApps.append(app)
            processedBundleIDs.insert(app.bundleID)
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
    
    private func detectInstalledApps() -> [AppInfo] {
        logMessage("Scanning for installed apps")
        var detectedApps: [AppInfo] = []
        
        // Use LSApplicationWorkspace to get all installed applications
        guard let workspace = NSClassFromString("LSApplicationWorkspace")?.perform(Selector(("defaultWorkspace")))?.takeUnretainedValue(),
              let applications = workspace.perform(Selector(("allApplications")))?.takeUnretainedValue() as? [AnyObject] else {
            logMessage("Failed to access application workspace")
            return []
        }
        
        // Known bundle ID patterns for each category
        let emulatorPatterns = ["emulator", "emu", "delta", "ppsspp", "retroarch", "provenance", "dolphin", "inds", "mame", "mupen", "openemu", "utmapp"]
        let jsAppPatterns = ["javascript", "js", "script", "node", "v8", "playjs", "jsbox", "scriptable"]
        let virtualMachinePatterns = ["vm", "virtualbox", "parallel", "qemu", "virtualpc", "bootcamp", "wine", "bluestack", "remote"]
        
        for app in applications {
            // Extract application info
            guard let bundleID = app.perform(Selector(("bundleIdentifier")))?.takeUnretainedValue() as? String,
                  let displayName = app.perform(Selector(("localizedName")))?.takeUnretainedValue() as? String else {
                continue
            }
            
            // Skip system apps
            if bundleID.hasPrefix("com.apple.") {
                continue
            }
            
            // Determine app category based on bundle ID or other properties
            let lowercaseBundleID = bundleID.lowercased()
            let lowercaseName = displayName.lowercased()
            var appCategory: AppCategory = .otherApps
            
            // Check for emulators
            if emulatorPatterns.contains(where: { pattern in 
                lowercaseBundleID.contains(pattern) || lowercaseName.contains(pattern)
            }) {
                appCategory = .emulators
            } 
            // Check for JavaScript apps
            else if jsAppPatterns.contains(where: { pattern in 
                lowercaseBundleID.contains(pattern) || lowercaseName.contains(pattern)
            }) {
                appCategory = .javascriptApps
            } 
            // Check for other virtualization/remote apps
            else if virtualMachinePatterns.contains(where: { pattern in 
                lowercaseBundleID.contains(pattern) || lowercaseName.contains(pattern)
            }) {
                appCategory = .otherApps
            }
            
            // Get app icon if available
            var iconName: String?
            if let iconsDictionary = app.perform(Selector(("iconsDictionary")))?.takeUnretainedValue() as? [AnyHashable: Any],
               let primaryIconDict = iconsDictionary["primary-app-icon"] as? [AnyHashable: Any],
               let iconFilePath = primaryIconDict["file-path"] as? String {
                iconName = iconFilePath
            }
            
            // Create AppInfo object
            let appInfo = AppInfo(
                id: UUID().uuidString,
                bundleID: bundleID,
                name: displayName,
                category: appCategory,
                iconName: iconName
            )
            
            detectedApps.append(appInfo)
            logMessage("Detected app: \(displayName) (\(bundleID)) - Category: \(appCategory.displayName)")
        }
        
        // Add predefined apps in case they're not installed but supported
        for app in AppInfo.allPredefinedApps where !detectedApps.contains(where: { $0.bundleID == app.bundleID }) {
            detectedApps.append(app)
        }
        
        logMessage("Completed app scan. Total apps found: \(detectedApps.count)")
        return detectedApps
    }
    
    // Load app icon from the filesystem
    func loadAppIcon(from path: String?) -> UIImage? {
        guard let iconPath = path else {
            return nil
        }
        
        if let iconImage = UIImage(contentsOfFile: iconPath) {
            return iconImage
        }
        
        return nil
    }
    
    // Real app icon loading from the installed application
    func getAppIcon(for bundleID: String) -> UIImage? {
        logMessage("Fetching icon for \(bundleID)")
        
        // First check if we have the app in our database
        guard let app = findApp(byBundleID: bundleID) else {
            logMessage("App not found in database: \(bundleID)")
            return UIImage(systemName: "app")
        }
        
        // Try to load icon from the saved path if we have one
        if let iconPath = app.iconName, let iconImage = loadAppIcon(from: iconPath) {
            logMessage("Loaded app icon from path: \(iconPath)")
            return iconImage
        }
        
        // Try to get the app icon directly using LSApplicationWorkspace
        if let iconImage = getAppIconDirectly(for: bundleID) {
            logMessage("Loaded app icon directly for: \(bundleID)")
            return iconImage
        }
        
        // Fallback to system icons based on category
        logMessage("Using fallback icon for \(bundleID)")
        switch app.category {
        case .emulators:
            return UIImage(systemName: "gamecontroller.fill")
        case .javascriptApps:
            return UIImage(systemName: "chevron.left.forwardslash.chevron.right")
        case .otherApps:
            return UIImage(systemName: "app.badge.fill")
        }
    }
    
    private func getAppIconDirectly(for bundleID: String) -> UIImage? {
        // Use LSApplicationWorkspace to get the app's icon directly
        guard let workspace = NSClassFromString("LSApplicationWorkspace")?.perform(Selector(("defaultWorkspace")))?.takeUnretainedValue() else {
            return nil
        }
        
        // Try to get app proxy
        guard let appProxy = workspace.perform(
            Selector(("applicationProxyForIdentifier:")),
            with: bundleID
        )?.takeUnretainedValue() else {
            return nil
        }
        
        // Try to get icon dictionary
        guard let iconsDictionary = appProxy.perform(Selector(("iconsDictionary")))?.takeUnretainedValue() as? [AnyHashable: Any] else {
            return nil
        }
        
        // Look for primary app icon
        guard let primaryIconDict = iconsDictionary["primary-app-icon"] as? [AnyHashable: Any],
              let iconFilePath = primaryIconDict["file-path"] as? String else {
            return nil
        }
        
        // Load the icon from file path
        return UIImage(contentsOfFile: iconFilePath)
    }
    
    private func logMessage(_ message: String) {
        if loggingEnabled {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timestamp)] AppManager: \(message)")
        }
    }
}