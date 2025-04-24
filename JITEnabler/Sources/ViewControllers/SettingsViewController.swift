import UIKit

class SettingsViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet private weak var backendURLTextField: UITextField!
    @IBOutlet private weak var deviceInfoLabel: UILabel!
    @IBOutlet private weak var clearSessionsButton: UIButton!
    @IBOutlet private weak var clearRecentAppsButton: UIButton!
    @IBOutlet private weak var resetDeviceButton: UIButton!
    @IBOutlet private weak var saveButton: UIButton!
    
    // MARK: - Properties
    private let sessionManager = SessionManager.shared
    private let appManager = InstalledAppManager.shared
    private let keychainHelper = KeychainHelper.shared
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        loadSettings()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        title = "Settings"
        
        // Setup text field
        backendURLTextField.delegate = self
        backendURLTextField.clearButtonMode = .whileEditing
        backendURLTextField.returnKeyType = .done
        
        // Setup buttons
        saveButton.layer.cornerRadius = 10
        saveButton.clipsToBounds = true
        
        clearSessionsButton.layer.cornerRadius = 10
        clearSessionsButton.clipsToBounds = true
        
        clearRecentAppsButton.layer.cornerRadius = 10
        clearRecentAppsButton.clipsToBounds = true
        
        resetDeviceButton.layer.cornerRadius = 10
        resetDeviceButton.clipsToBounds = true
        resetDeviceButton.backgroundColor = .systemRed
    }
    
    private func loadSettings() {
        // Load backend URL
        backendURLTextField.text = sessionManager.backendURL
        
        // Load device info
        if let deviceInfo = sessionManager.deviceInfo {
            deviceInfoLabel.text = """
            Device: \(deviceInfo.deviceName)
            Model: \(deviceInfo.deviceModel)
            iOS: \(deviceInfo.iosVersion)
            ID: \(deviceInfo.udid)
            """
        } else {
            deviceInfoLabel.text = "No device info available"
        }
    }
    
    // MARK: - Actions
    
    @IBAction func saveButtonTapped(_ sender: UIButton) {
        saveSettings()
    }
    
    @IBAction func clearSessionsButtonTapped(_ sender: UIButton) {
        // Show confirmation alert
        let alert = UIAlertController(
            title: "Clear Sessions",
            message: "Are you sure you want to clear all JIT sessions?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            self?.sessionManager.clearSessions()
            
            // Show success message
            let successAlert = UIAlertController(
                title: "Success",
                message: "All JIT sessions have been cleared",
                preferredStyle: .alert
            )
            successAlert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(successAlert, animated: true)
        })
        
        present(alert, animated: true)
    }
    
    @IBAction func clearRecentAppsButtonTapped(_ sender: UIButton) {
        // Show confirmation alert
        let alert = UIAlertController(
            title: "Clear Recent Apps",
            message: "Are you sure you want to clear all recent apps?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            self?.appManager.clearRecentApps()
            
            // Show success message
            let successAlert = UIAlertController(
                title: "Success",
                message: "All recent apps have been cleared",
                preferredStyle: .alert
            )
            successAlert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(successAlert, animated: true)
        })
        
        present(alert, animated: true)
    }
    
    @IBAction func resetDeviceButtonTapped(_ sender: UIButton) {
        // Show confirmation alert
        let alert = UIAlertController(
            title: "Reset Device",
            message: "Are you sure you want to reset the device? This will delete the authentication token and require re-registration.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive) { [weak self] _ in
            // Delete token
            self?.keychainHelper.deleteToken()
            
            // Show success message
            let successAlert = UIAlertController(
                title: "Success",
                message: "Device has been reset. You will need to register again.",
                preferredStyle: .alert
            )
            successAlert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                // Go back to home screen
                self?.navigationController?.popToRootViewController(animated: true)
            })
            self?.present(successAlert, animated: true)
        })
        
        present(alert, animated: true)
    }
    
    // MARK: - Private Methods
    
    private func saveSettings() {
        guard let backendURL = backendURLTextField.text, !backendURL.isEmpty else {
            // Show error message
            let alert = UIAlertController(
                title: "Error",
                message: "Backend URL cannot be empty",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        // Validate URL
        guard URL(string: backendURL) != nil else {
            // Show error message
            let alert = UIAlertController(
                title: "Error",
                message: "Invalid URL format",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        // Save backend URL
        sessionManager.backendURL = backendURL
        
        // Show success message
        let alert = UIAlertController(
            title: "Success",
            message: "Settings saved successfully",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITextFieldDelegate

extension SettingsViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        if textField == backendURLTextField {
            saveSettings()
        }
        
        return true
    }
}