import Foundation

// MARK: - JIT Enablement Service
class JITEnablementService {
    private let urlSession: URLSession
    private let responseHandler: APIResponseHandler
    private let loggingEnabled: Bool
    
    init(urlSession: URLSession = .shared, responseHandler: APIResponseHandler = APIResponseHandler(), loggingEnabled: Bool = true) {
        self.urlSession = urlSession
        self.responseHandler = responseHandler
        self.loggingEnabled = loggingEnabled
    }
    
    // Enable JIT for a specific app
    func enableJIT(
        bundleID: String,
        appName: String,
        deviceInfo: DeviceInfo,
        token: String,
        baseURL: String,
        completion: @escaping (Result<JITEnablementResponse, Error>) -> Void
    ) {
        logMessage("Enabling JIT for bundle ID: \(bundleID)")
        
        // Create URL for the JIT enablement endpoint
        guard let url = URL(string: "\(baseURL)/enable-jit") else {
            completion(.failure(APIError.invalidURL(url: "\(baseURL)/enable-jit")))
            return
        }
        
        // Prepare request parameters
        let parameters: [String: Any] = [
            "bundle_id": bundleID,
            "app_name": appName,
            "device_info": deviceInfo.toDictionary()
        ]
        
        // Create request object
        let apiRequest = APIRequest(
            url: url,
            method: .post,
            parameters: parameters,
            requiresAuthentication: true
        )
        
        // Create URLRequest with token
        let request = apiRequest.asURLRequest(token: token)
        
        // Execute request
        let task = urlSession.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            self.responseHandler.handleResponse(
                data: data,
                response: response,
                error: error,
                completion: { (result: Result<JITEnablementResponse, Error>) in
                    switch result {
                    case .success(let response):
                        self.logMessage("JIT enablement successful for \(bundleID)")
                        completion(.success(response))
                        
                    case .failure(let error):
                        self.logMessage("JIT enablement failed for \(bundleID): \(error.localizedDescription)")
                        completion(.failure(error))
                    }
                }
            )
        }
        
        task.resume()
    }
    
    // Get JIT session status
    func getSessionStatus(
        sessionID: String,
        token: String,
        baseURL: String,
        completion: @escaping (Result<JITSession, Error>) -> Void
    ) {
        logMessage("Getting session status for ID: \(sessionID)")
        
        // Create URL for the session status endpoint
        guard let url = URL(string: "\(baseURL)/session/\(sessionID)") else {
            completion(.failure(APIError.invalidURL(url: "\(baseURL)/session/\(sessionID)")))
            return
        }
        
        // Create request object
        let apiRequest = APIRequest(
            url: url,
            method: .get,
            requiresAuthentication: true
        )
        
        // Create URLRequest with token
        let request = apiRequest.asURLRequest(token: token)
        
        // Execute request
        let task = urlSession.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            self.responseHandler.handleResponse(
                data: data,
                response: response,
                error: error,
                completion: { (result: Result<JITSession, Error>) in
                    switch result {
                    case .success(let session):
                        self.logMessage("Session status received for ID: \(sessionID)")
                        completion(.success(session))
                        
                    case .failure(let error):
                        self.logMessage("Failed to get session status for ID: \(sessionID): \(error.localizedDescription)")
                        completion(.failure(error))
                    }
                }
            )
        }
        
        task.resume()
    }
    
    // MARK: - Private Helpers
    
    private func logMessage(_ message: String) {
        if loggingEnabled {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timestamp)] JITEnablement: \(message)")
        }
    }
}
