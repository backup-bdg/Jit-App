import UIKit

class AppListViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var emptyStateView: UIView!
    @IBOutlet private weak var emptyStateLabel: UILabel!
    @IBOutlet private weak var addAppButton: UIButton!
    
    // MARK: - Properties
    var category: AppCategory!
    
    private let appManager = InstalledAppManager.shared
    private let jitService = JITService.shared
    
    private var apps: [AppInfo] = []
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupTableView()
        loadApps()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        title = category.displayName
        
        // Setup add button
        let addButton = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addButtonTapped)
        )
        navigationItem.rightBarButtonItem = addButton
        
        // Setup empty state
        emptyStateLabel.text = "No \(category.displayName.lowercased()) found"
        addAppButton.layer.cornerRadius = 10
        addAppButton.clipsToBounds = true
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        
        // Register cell
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "AppCell")
    }
    
    private func loadApps() {
        apps = appManager.getApps(for: category)
        tableView.reloadData()
        
        // Show/hide empty state
        emptyStateView.isHidden = !apps.isEmpty
        tableView.isHidden = apps.isEmpty
    }
    
    // MARK: - Actions
    
    @IBAction func addAppButtonTapped(_ sender: UIButton) {
        showAddAppAlert()
    }
    
    @objc private func addButtonTapped() {
        showAddAppAlert()
    }
    
    // MARK: - Private Methods
    
    private func showAddAppAlert() {
        let alert = UIAlertController(
            title: "Add Custom App",
            message: "Enter the app details",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "App Name"
        }
        
        alert.addTextField { textField in
            textField.placeholder = "Bundle ID (e.g., com.example.app)"
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self] _ in
            guard let self = self,
                  let nameField = alert.textFields?[0],
                  let bundleIDField = alert.textFields?[1],
                  let name = nameField.text, !name.isEmpty,
                  let bundleID = bundleIDField.text, !bundleID.isEmpty else {
                return
            }
            
            // Create new app
            let newApp = AppInfo(
                bundleID: bundleID,
                name: name,
                category: self.category
            )
            
            // Add to custom apps
            self.appManager.addCustomApp(newApp)
            
            // Reload apps
            self.loadApps()
        })
        
        present(alert, animated: true)
    }
    
    private func enableJIT(for app: AppInfo) {
        // Check if device is registered
        guard jitService.isDeviceRegistered() else {
            // Show alert to register device first
            let alert = UIAlertController(
                title: "Device Not Registered",
                message: "Please register your device first",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Register", style: .default) { [weak self] _ in
                self?.registerDevice()
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(alert, animated: true)
            return
        }
        
        // Show loading indicator
        let loadingAlert = UIAlertController(title: "Enabling JIT", message: "Please wait...", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        jitService.enableJIT(for: app) { [weak self] result in
            // Dismiss loading indicator
            loadingAlert.dismiss(animated: true) {
                switch result {
                case .success(let response):
                    // Add to recent apps
                    self?.appManager.addRecentApp(app)
                    
                    // Show JIT status screen
                    let storyboard = UIStoryboard(name: "Main", bundle: nil)
                    let jitStatusVC = storyboard.instantiateViewController(withIdentifier: "JITStatusViewController") as! JITStatusViewController
                    jitStatusVC.configure(with: app, response: response)
                    self?.navigationController?.pushViewController(jitStatusVC, animated: true)
                    
                case .failure(let error):
                    // Show error message
                    let errorAlert = UIAlertController(
                        title: "JIT Enablement Failed",
                        message: error.localizedDescription,
                        preferredStyle: .alert
                    )
                    errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(errorAlert, animated: true)
                }
            }
        }
    }
    
    private func registerDevice() {
        // Show loading indicator
        let loadingAlert = UIAlertController(title: "Registering Device", message: "Please wait...", preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        jitService.registerDevice { [weak self] result in
            // Dismiss loading indicator
            loadingAlert.dismiss(animated: true) {
                switch result {
                case .success:
                    // Show success message
                    let successAlert = UIAlertController(
                        title: "Success",
                        message: "Device registered successfully",
                        preferredStyle: .alert
                    )
                    successAlert.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(successAlert, animated: true)
                    
                case .failure(let error):
                    // Show error message
                    let errorAlert = UIAlertController(
                        title: "Registration Failed",
                        message: error.localizedDescription,
                        preferredStyle: .alert
                    )
                    errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(errorAlert, animated: true)
                }
            }
        }
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource

extension AppListViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return apps.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AppCell", for: indexPath)
        
        // Configure cell
        let app = apps[indexPath.row]
        
        var configuration = UIListContentConfiguration.cell()
        configuration.text = app.name
        configuration.secondaryText = app.bundleID
        configuration.image = UIImage(systemName: "app")
        
        cell.contentConfiguration = configuration
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let app = apps[indexPath.row]
        enableJIT(for: app)
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let app = apps[indexPath.row]
        
        // Only allow deleting custom apps
        if appManager.customApps.contains(where: { $0.bundleID == app.bundleID }) {
            let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
                self?.appManager.removeCustomApp(app)
                self?.loadApps()
                completion(true)
            }
            
            return UISwipeActionsConfiguration(actions: [deleteAction])
        }
        
        return nil
    }
}