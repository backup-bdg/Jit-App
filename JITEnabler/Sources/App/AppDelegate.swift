import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    // Services that need to be initialized at app startup
    private let jitService = JITService.shared
    private let appManager = InstalledAppManager.shared
    private let sessionManager = SessionManager.shared
    
    // App-level configuration
    private let loggingEnabled = true
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Initialize app appearance
        setupAppearance()
        
        // Log app startup
        logAppInfo()
        
        // Pre-warm the app cache
        appManager.refreshCachedAppsIfNeeded()
        
        // Verify backend URL is set
        if sessionManager.backendURL == nil {
            sessionManager.backendURL = "https://jit-backend-dna8.onrender.com"
            logMessage("Set default backend URL")
        }
        
        // Register for background fetch if supported
        setupBackgroundRefresh(application)
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        logMessage("Creating new scene session")
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        logMessage("Discarded \(sceneSessions.count) scene sessions")
    }
    
    // MARK: - Background Tasks
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        logMessage("Performing background fetch")
        
        // Check for any pending JIT sessions and update their status
        if let token = KeychainHelper.shared.getToken() {
            jitService.getDeviceSessions { result in
                switch result {
                case .success(let sessions):
                    self.logMessage("Updated \(sessions.count) sessions in background")
                    completionHandler(.newData)
                    
                case .failure(let error):
                    self.logMessage("Background fetch failed: \(error.localizedDescription)")
                    completionHandler(.failed)
                }
            }
        } else {
            // No authentication token, nothing to fetch
            completionHandler(.noData)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAppearance() {
        // Configure navigation bar appearance
        if #available(iOS 15.0, *) {
            let navigationBarAppearance = UINavigationBarAppearance()
            navigationBarAppearance.configureWithDefaultBackground()
            navigationBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.black]
            navigationBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.black]
            
            UINavigationBar.appearance().standardAppearance = navigationBarAppearance
            UINavigationBar.appearance().compactAppearance = navigationBarAppearance
            UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance
        }
        
        // Configure tab bar appearance if needed in the future
        if #available(iOS 15.0, *) {
            let tabBarAppearance = UITabBarAppearance()
            tabBarAppearance.configureWithDefaultBackground()
            UITabBar.appearance().standardAppearance = tabBarAppearance
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
    }
    
    private func setupBackgroundRefresh(_ application: UIApplication) {
        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
    }
    
    private func logAppInfo() {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        let deviceInfo = DeviceInfo.current()
        
        logMessage("==================================================")
        logMessage("JIT Enabler v\(appVersion) (Build \(buildNumber)) started")
        logMessage("Device: \(deviceInfo.deviceName) (\(deviceInfo.deviceModel))")
        logMessage("iOS Version: \(deviceInfo.iosVersion)")
        logMessage("Device ID: \(deviceInfo.udid)")
        logMessage("==================================================")
    }
    
    private func logMessage(_ message: String) {
        if loggingEnabled {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timestamp)] AppDelegate: \(message)")
        }
    }
}