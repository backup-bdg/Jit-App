import UIKit

class HomeViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet private weak var recentAppsCollectionView: UICollectionView!
    @IBOutlet private weak var categoriesTableView: UITableView!
    @IBOutlet private weak var statusLabel: UILabel!
    @IBOutlet private weak var registerButton: UIButton!
    
    // MARK: - Properties
    private let jitService = JITService.shared
    private let appManager = InstalledAppManager.shared
    private let sessionManager = SessionManager.shared
    
    private var recentApps: [AppInfo] = []
    private var categories: [AppCategory] = AppCategory.allCases
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupCollectionView()
        setupTableView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateUI()
        loadRecentApps()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        title = "JIT Enabler"
        
        // Setup navigation bar
        navigationController?.navigationBar.prefersLargeTitles = true
        
        let settingsButton = UIBarButtonItem(
            image: UIImage(systemName: "gear"),
            style: .plain,
            target: self,
            action: #selector(settingsButtonTapped)
        )
        navigationItem.rightBarButtonItem = settingsButton
        
        // Setup register button
        registerButton.layer.cornerRadius = 10
        registerButton.clipsToBounds = true
    }
    
    private func setupCollectionView() {
        recentAppsCollectionView.delegate = self
        recentAppsCollectionView.dataSource = self
        
        // Register a standard cell that supports content configuration
        recentAppsCollectionView.register(UICollectionViewListCell.self, forCellWithReuseIdentifier: "RecentAppCell")
    }
    
    private func setupTableView() {
        categoriesTableView.delegate = self
        categoriesTableView.dataSource = self
        
        // Register cell
        categoriesTableView.register(UITableViewCell.self, forCellReuseIdentifier: "CategoryCell")
    }
    
    private func updateUI() {
        if jitService.isDeviceRegistered() {
            statusLabel.text = "Device registered"
            statusLabel.textColor = .systemGreen
            registerButton.isHidden = true
        } else {
            statusLabel.text = "Device not registered"
            statusLabel.textColor = .systemRed
            registerButton.isHidden = false
        }
    }
    
    private func loadRecentApps() {
        recentApps = appManager.getRecentApps()
        recentAppsCollectionView.reloadData()
    }
    
    // MARK: - Actions
    
    @IBAction func registerButtonTapped(_ sender: UIButton) {
        registerDevice()
    }
    
    @objc private func settingsButtonTapped() {
        performSegue(withIdentifier: "ShowSettings", sender: nil)
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowAppList", let category = sender as? AppCategory {
            let appListVC = segue.destination as! AppListViewController
            appListVC.category = category
        }
    }
    
    // MARK: - Private Methods
    
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
                    
                    // Update UI
                    self?.updateUI()
                    
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

// MARK: - UICollectionViewDelegate, UICollectionViewDataSource

extension HomeViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return recentApps.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "RecentAppCell", for: indexPath)
        
        // Configure cell
        let app = recentApps[indexPath.item]
        
        // Configure cell with app info
        var configuration = UIListContentConfiguration.cell()
        configuration.text = app.name
        configuration.secondaryText = app.bundleID
        configuration.image = UIImage(systemName: "app")
        
        cell.contentConfiguration = configuration
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let app = recentApps[indexPath.item]
        enableJIT(for: app)
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource

extension HomeViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return categories.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CategoryCell", for: indexPath)
        
        // Configure cell
        let category = categories[indexPath.row]
        
        var configuration = UIListContentConfiguration.cell()
        configuration.text = category.displayName
        
        // Set appropriate icon for each category
        switch category {
        case .emulators:
            configuration.image = UIImage(systemName: "gamecontroller")
        case .javascriptApps:
            configuration.image = UIImage(systemName: "chevron.left.forwardslash.chevron.right")
        case .otherApps:
            configuration.image = UIImage(systemName: "app.badge")
        }
        
        cell.contentConfiguration = configuration
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let category = categories[indexPath.row]
        performSegue(withIdentifier: "ShowAppList", sender: category)
    }
}

// MARK: - JIT Enablement

extension HomeViewController {
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
}