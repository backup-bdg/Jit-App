import Foundation

// MARK: - Session Management Service
class SessionManagementService {
    private let urlSession: URLSession
    private let responseHandler: APIResponseHandler
    private let loggingEnabled: Bool
    
    init(urlSession: URLSession = .shared, responseHandler: APIResponseHandler = APIResponseHandler(), loggingEnabled: Bool = true) {
        self.urlSession = urlSession
        self.responseHandler = responseHandler
        self.loggingEnabled = loggingEnabled
    }
    
    // Get all device sessions
    func getDeviceSessions(
        token: String,
        baseURL: String,
        completion: @escaping (Result<[JITSession], Error>) -> Void
    ) {
        logMessage("Fetching all device sessions")
        
        // Create URL for the device sessions endpoint
        guard let url = URL(string: "\(baseURL)/sessions") else {
            completion(.failure(APIError.invalidURL(url: "\(baseURL)/sessions")))
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
                completion: { (result: Result<[JITSession], Error>) in
                    switch result {
                    case .success(let sessions):
                        self.logMessage("Retrieved \(sessions.count) device sessions")
                        completion(.success(sessions))
                        
                    case .failure(let error):
                        self.logMessage("Failed to retrieve device sessions: \(error.localizedDescription)")
                        completion(.failure(error))
                    }
                }
            )
        }
        
        task.resume()
    }
    
    // Cancel a JIT session
    func cancelSession(
        sessionID: String,
        token: String,
        baseURL: String,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        logMessage("Cancelling session with ID: \(sessionID)")
        
        // Create URL for the session cancellation endpoint
        guard let url = URL(string: "\(baseURL)/session/\(sessionID)/cancel") else {
            completion(.failure(APIError.invalidURL(url: "\(baseURL)/session/\(sessionID)/cancel")))
            return
        }
        
        // Create request object
        let apiRequest = APIRequest(
            url: url,
            method: .post,
            requiresAuthentication: true
        )
        
        // Create URLRequest with token
        let request = apiRequest.asURLRequest(token: token)
        
        // Execute request
        let task = urlSession.dataTask(with: request) { [weak self] _, response, error in
            guard let self = self else { return }
            
            // Handle response with a simple success/failure
            if let error = error {
                self.logMessage("Session cancellation failed: \(error.localizedDescription)")
                completion(.failure(APIError.connectionError(details: error.localizedDescription)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                self.logMessage("Session cancellation failed: Invalid response")
                completion(.failure(APIError.responseError(details: "Invalid response")))
                return
            }
            
            // Check if the request was successful based on HTTP status code
            if 200...299 ~= httpResponse.statusCode {
                self.logMessage("Session cancellation successful")
                completion(.success(true))
            } else {
                self.logMessage("Session cancellation failed with status code: \(httpResponse.statusCode)")
                completion(.failure(APIError.serverError(code: httpResponse.statusCode)))
            }
        }
        
        task.resume()
    }
    
    // MARK: - Private Helpers
    
    private func logMessage(_ message: String) {
        if loggingEnabled {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timestamp)] SessionManagement: \(message)")
        }
    }
}
