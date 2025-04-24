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
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        updateUI()
    }
    
    // MARK: - Configuration
    
    func configure(with app: AppInfo, response: JITEnablementResponse) {
        self.app = app
        self.jitResponse = response
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
    }
    
    private func updateUI() {
        guard let app = app, let jitResponse = jitResponse else { return }
        
        // Update labels
        appNameLabel.text = app.name
        bundleIDLabel.text = app.bundleID
        statusLabel.text = "JIT Enabled"
        methodLabel.text = "Method: \(jitResponse.method)"
        
        // Format instructions
        var instructionsText = "Session ID: \(jitResponse.sessionId)\n\n"
        instructionsText += "Token: \(jitResponse.token)\n\n"
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
    }
    
    // MARK: - Actions
    
    @IBAction func applyButtonTapped(_ sender: UIButton) {
        applyJITInstructions()
    }
    
    @IBAction func doneButtonTapped(_ sender: UIButton) {
        // Return to root view controller
        navigationController?.popToRootViewController(animated: true)
    }
    
    // MARK: - Private Methods
    
    private func applyJITInstructions() {
        // Show loading state
        applyButton.isHidden = true
        activityIndicator.startAnimating()
        
        jitService.applyJITInstructions(jitResponse.instructions) { [weak self] success in
            // Hide loading state
            self?.activityIndicator.stopAnimating()
            
            if success {
                // Show success state
                self?.statusLabel.text = "JIT Applied Successfully"
                self?.statusLabel.textColor = .systemGreen
                self?.doneButton.isHidden = false
                
                // Show success message
                let alert = UIAlertController(
                    title: "Success",
                    message: "JIT has been successfully enabled for \(self?.app.name ?? "the app"). You can now launch the app and use JIT features.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(alert, animated: true)
            } else {
                // Show failure state
                self?.statusLabel.text = "JIT Application Failed"
                self?.statusLabel.textColor = .systemRed
                self?.applyButton.isHidden = false
                
                // Show error message
                let alert = UIAlertController(
                    title: "Error",
                    message: "Failed to apply JIT instructions. Please try again.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(alert, animated: true)
            }
        }
    }
}