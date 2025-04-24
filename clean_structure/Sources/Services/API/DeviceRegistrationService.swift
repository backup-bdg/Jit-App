import Foundation

// MARK: - Device Registration Service
class DeviceRegistrationService {
    private let urlSession: URLSession
    private let responseHandler: APIResponseHandler
    private let loggingEnabled: Bool
    
    init(urlSession: URLSession = .shared, responseHandler: APIResponseHandler = APIResponseHandler(), loggingEnabled: Bool = true) {
        self.urlSession = urlSession
        self.responseHandler = responseHandler
        self.loggingEnabled = loggingEnabled
    }
    
    // Register a device with the JIT server
    func registerDevice(deviceInfo: DeviceInfo, baseURL: String, completion: @escaping (Result<String, Error>) -> Void) {
        logMessage("Registering device: \(deviceInfo.deviceModel)")
        
        // Create URL for the registration endpoint
        guard let url = URL(string: "\(baseURL)/register") else {
            completion(.failure(APIError.invalidURL(url: "\(baseURL)/register")))
            return
        }
        
        // Create request object
        let apiRequest = APIRequest(
            url: url,
            method: .post,
            parameters: deviceInfo.toDictionary()
        )
        
        // Create URLRequest
        let request = apiRequest.asURLRequest()
        
        // Execute request
        let task = urlSession.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            self.responseHandler.handleStringResponse(
                data: data,
                response: response,
                error: error,
                completion: { result in
                    switch result {
                    case .success(let token):
                        self.logMessage("Device registration successful")
                        completion(.success(token))
                        
                    case .failure(let error):
                        self.logMessage("Device registration failed: \(error.localizedDescription)")
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
            print("[\(timestamp)] DeviceRegistration: \(message)")
        }
    }
}
