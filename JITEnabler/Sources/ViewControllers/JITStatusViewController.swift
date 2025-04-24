import UIKit

class JITStatusViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet private weak var appNameLabel: UILabel!
    @IBOutlet private weak var bundleIDLabel: UILabel!
    @IBOutlet private weak var statusLabel: UILabel!
    @IBOutlet private weak var methodLabel: UILabel!
    @IBOutlet private weak var instructionsTextView: UITextView!
    @IBOutlet private weak var applyButton: UIButton!
    @IBOutlet private weak var doneButton: UIButton!
    @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!
    
    // MARK: - Properties
    private var app: AppInfo!
    private var jitResponse: JITEnablementResponse!
    private let jitService = JITService.shared
    private let loggingEnabled = true
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        updateUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        logMessage("Viewing JIT status for \(app?.name ?? "unknown app")")
    }
    
    // MARK: - Configuration
    
    func configure(with app: AppInfo, response: JITEnablementResponse) {
        self.app = app
        self.jitResponse = response
        logMessage("Configured with app: \(app.name) and session ID: \(response.sessionId)")
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        title = "JIT Status"
        
        // Setup buttons
        applyButton.layer.cornerRadius = 10
        applyButton.clipsToBounds = true
        
        doneButton.layer.cornerRadius = 10
        doneButton.clipsToBounds = true
        doneButton.isHidden = true
        
        // Setup text view
        instructionsTextView.layer.cornerRadius = 8
        instructionsTextView.clipsToBounds = true
        instructionsTextView.isEditable = false
        
        // Set status label initial state
        statusLabel.text = "Waiting to Apply JIT"
        statusLabel.textColor = .systemOrange
    }
    
    private func updateUI() {
        guard let app = app, let jitResponse = jitResponse else { 
            logMessage("Cannot update UI: app or jitResponse is nil")
            return 
        }
        
        // Update labels
        appNameLabel.text = app.name
        bundleIDLabel.text = app.bundleID
        methodLabel.text = "Method: \(jitResponse.method)"
        
        // Format instructions
        var instructionsText = "Session ID: \(jitResponse.sessionId)\n\n"
        
        // Mask the token for security in the UI
        let maskedToken = maskToken(jitResponse.token)
        instructionsText += "Token: \(maskedToken)\n\n"
        
        instructionsText += "Instructions:\n"
        
        if let toggleWx = jitResponse.instructions.toggleWxMemory {
            instructionsText += "- Toggle W^X Memory: \(toggleWx ? "Yes" : "No")\n"
        }
        
        instructionsText += "- Set CS_DEBUGGED Flag: \(jitResponse.instructions.setCsDebugged ? "Yes" : "No")\n"
        
        if let memoryRegions = jitResponse.instructions.memoryRegions {
            instructionsText += "\nMemory Regions:\n"
            for (index, region) in memoryRegions.enumerated() {
                instructionsText += "Region \(index + 1):\n"
                instructionsText += "- Address: \(region.address)\n"
                instructionsText += "- Size: \(region.size)\n"
                instructionsText += "- Permissions: \(region.permissions)\n"
            }
        }
        
        instructionsTextView.text = instructionsText
        
        // Check if JIT is already enabled for this app
        if jitService.isJITEnabled(for: app.bundleID) {
            statusLabel.text = "JIT Already Enabled"
            statusLabel.textColor = .systemGreen
            applyButton.isEnabled = false
            applyButton.alpha = 0.5
            doneButton.isHidden = false
        }
    }
    
    // MARK: - Actions
    
    @IBAction func applyButtonTapped(_ sender: UIButton) {
        applyJITInstructions()
    }
    
    @IBAction func doneButtonTapped(_ sender: UIButton) {
        logMessage("Done button tapped, returning to root view controller")
        // Return to root view controller
        navigationController?.popToRootViewController(animated: true)
    }
    
    // MARK: - Private Methods
    
    private func applyJITInstructions() {
        guard let app = app, let jitResponse = jitResponse else {
            logMessage("Cannot apply JIT instructions: app or jitResponse is nil")
            showErrorAlert(message: "Missing app information. Please try again.")
            return
        }
        
        logMessage("Starting to apply JIT instructions for \(app.name)")
        
        // Show loading state
        applyButton.isHidden = true
        statusLabel.text = "Applying JIT..."
        statusLabel.textColor = .systemBlue
        activityIndicator.startAnimating()
        
        // Pass the app information to the JIT service
        jitService.applyJITInstructions(jitResponse.instructions, for: app) { [weak self] success in
            guard let self = self else { return }
            
            // Hide loading state
            self.activityIndicator.stopAnimating()
            
            if success {
                self.logMessage("JIT instructions applied successfully for \(app.name)")
                
                // Show success state
                self.statusLabel.text = "JIT Applied Successfully"
                self.statusLabel.textColor = .systemGreen
                self.doneButton.isHidden = false
                
                // Show success message
                let alert = UIAlertController(
                    title: "Success",
                    message: "JIT has been successfully enabled for \(app.name). You can now launch the app and use JIT features.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            } else {
                self.logMessage("Failed to apply JIT instructions for \(app.name)")
                
                // Show failure state
                self.statusLabel.text = "JIT Application Failed"
                self.statusLabel.textColor = .systemRed
                self.applyButton.isHidden = false
                
                // Show error message
                self.showErrorAlert(message: "Failed to apply JIT instructions. Please try again.")
            }
        }
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func maskToken(_ token: String) -> String {
        if token.count <= 8 {
            return token
        }
        
        let prefix = String(token.prefix(4))
        let suffix = String(token.suffix(4))
        return "\(prefix)...\(suffix)"
    }
    
    private func logMessage(_ message: String) {
        if loggingEnabled {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timestamp)] JITStatusVC: \(message)")
        }
    }
}