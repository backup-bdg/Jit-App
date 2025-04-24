import Foundation

class APIClient {
    static let shared = APIClient()
    
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let retryLimit = 3
    private let retryDelay: TimeInterval = 0.5
    private let loggingEnabled = true
    
    private var activeTasks: [URLSessionTask] = []
    private let taskLock = NSLock()
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        config.httpMaximumConnectionsPerHost = 5
        
        self.session = URLSession(configuration: config)
        
        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }
    
    deinit {
        cancelAllRequests()
    }
    
    // MARK: - Request Management
    
    private func addTask(_ task: URLSessionTask) {
        taskLock.lock()
        activeTasks.append(task)
        taskLock.unlock()
    }
    
    private func removeTask(_ task: URLSessionTask) {
        taskLock.lock()
        activeTasks.removeAll { $0 == task }
        taskLock.unlock()
    }
    
    func cancelAllRequests() {
        taskLock.lock()
        activeTasks.forEach { $0.cancel() }
        activeTasks.removeAll()
        taskLock.unlock()
    }
    
    // MARK: - API Endpoints
    
    func registerDevice(deviceInfo: DeviceInfo, baseURL: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/register") else {
            completion(.failure(APIError.invalidURL(url: "\(baseURL)/register")))
            return
        }
        
        logMessage("Registering device: \(deviceInfo.deviceModel)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("JITEnabler/1.0", forHTTPHeaderField: "User-Agent")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: deviceInfo.toDictionary(), options: [])
            request.httpBody = jsonData
            
            executeRequest(request, retryCount: 0) { [weak self] data, response, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.logMessage("Registration failed: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(APIError.invalidResponse))
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    // Try to extract error message from response
                    var errorMessage = "Server error with status code: \(httpResponse.statusCode)"
                    if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let message = json["message"] as? String {
                        errorMessage = message
                    }
                    
                    self.logMessage("Registration failed: \(errorMessage)")
                    completion(.failure(APIError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(APIError.noData))
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let token = json["token"] as? String {
                            self.logMessage("Registration successful")
                            completion(.success(token))
                        } else if let error = json["error"] as? String {
                            self.logMessage("Registration failed: \(error)")
                            completion(.failure(APIError.serviceError(message: error)))
                        } else {
                            completion(.failure(APIError.decodingError(details: "Missing token in response")))
                        }
                    } else {
                        completion(.failure(APIError.decodingError(details: "Invalid JSON format")))
                    }
                } catch {
                    self.logMessage("Failed to parse registration response: \(error.localizedDescription)")
                    completion(.failure(APIError.decodingError(details: error.localizedDescription)))
                }
            }
        } catch {
            logMessage("Failed to serialize device info: \(error.localizedDescription)")
            completion(.failure(APIError.encodingError(details: error.localizedDescription)))
        }
    }
    
    func enableJIT(bundleID: String, token: String, baseURL: String, completion: @escaping (Result<JITEnablementResponse, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/enable-jit") else {
            completion(.failure(APIError.invalidURL(url: "\(baseURL)/enable-jit")))
            return
        }
        
        logMessage("Enabling JIT for bundle ID: \(bundleID)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("JITEnabler/1.0", forHTTPHeaderField: "User-Agent")
        
        // Get the app's display name if available
        let appName = bundleID.components(separatedBy: ".").last ?? "App"
        
        let requestBody: [String: Any] = [
            "bundle_id": bundleID,
            "app_info": [
                "name": appName,
                "device_info": DeviceInfo.current().toDictionary()
            ]
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: [])
            request.httpBody = jsonData
            
            executeRequest(request, retryCount: 0) { [weak self] data, response, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.logMessage("JIT enablement failed: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(APIError.invalidResponse))
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    // Try to extract error message from response
                    var errorMessage = "Server error with status code: \(httpResponse.statusCode)"
                    if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let message = json["message"] as? String {
                        errorMessage = message
                    }
                    
                    self.logMessage("JIT enablement failed: \(errorMessage)")
                    completion(.failure(APIError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(APIError.noData))
                    return
                }
                
                do {
                    let response = try self.decoder.decode(JITEnablementResponse.self, from: data)
                    self.logMessage("JIT enablement successful: \(response.method)")
                    completion(.success(response))
                } catch {
                    self.logMessage("Failed to parse JIT enablement response: \(error.localizedDescription)")
                    
                    // Try to parse the error message from the JSON
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = json["message"] as? String {
                        completion(.failure(APIError.serviceError(message: errorMessage)))
                    } else {
                        completion(.failure(APIError.decodingError(details: error.localizedDescription)))
                    }
                }
            }
        } catch {
            logMessage("Failed to serialize JIT request: \(error.localizedDescription)")
            completion(.failure(APIError.encodingError(details: error.localizedDescription)))
        }
    }
    
    func getSessionStatus(sessionID: String, token: String, baseURL: String, completion: @escaping (Result<JITSession, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/session/\(sessionID)") else {
            completion(.failure(APIError.invalidURL(url: "\(baseURL)/session/\(sessionID)")))
            return
        }
        
        logMessage("Getting status for session: \(sessionID)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("JITEnabler/1.0", forHTTPHeaderField: "User-Agent")
        
        executeRequest(request, retryCount: 0) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.logMessage("Failed to get session status: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to extract error message from response
                var errorMessage = "Server error with status code: \(httpResponse.statusCode)"
                if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["message"] as? String {
                    errorMessage = message
                }
                
                self.logMessage("Failed to get session status: \(errorMessage)")
                completion(.failure(APIError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)))
                return
            }
            
            guard let data = data else {
                completion(.failure(APIError.noData))
                return
            }
            
            do {
                // Try to decode directly
                let session = try self.decoder.decode(JITSession.self, from: data)
                self.logMessage("Session status retrieved: \(session.status)")
                completion(.success(session))
            } catch {
                // If direct decoding fails, try to manually extract session data
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let sessionData = json["session"] as? [String: Any] {
                        let sessionJSON = try JSONSerialization.data(withJSONObject: sessionData, options: [])
                        let session = try self.decoder.decode(JITSession.self, from: sessionJSON)
                        self.logMessage("Session status retrieved (via manual parsing): \(session.status)")
                        completion(.success(session))
                    } else {
                        self.logMessage("Failed to parse session status response: \(error.localizedDescription)")
                        completion(.failure(APIError.decodingError(details: error.localizedDescription)))
                    }
                } catch {
                    self.logMessage("Failed to parse session status response: \(error.localizedDescription)")
                    completion(.failure(APIError.decodingError(details: error.localizedDescription)))
                }
            }
        }
    }
    
    func getDeviceSessions(token: String, baseURL: String, completion: @escaping (Result<[JITSession], Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/device/sessions") else {
            completion(.failure(APIError.invalidURL(url: "\(baseURL)/device/sessions")))
            return
        }
        
        logMessage("Getting all device sessions")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("JITEnabler/1.0", forHTTPHeaderField: "User-Agent")
        
        executeRequest(request, retryCount: 0) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.logMessage("Failed to get device sessions: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(APIError.invalidResponse))
                return
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                // Try to extract error message from response
                var errorMessage = "Server error with status code: \(httpResponse.statusCode)"
                if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["message"] as? String {
                    errorMessage = message
                }
                
                self.logMessage("Failed to get device sessions: \(errorMessage)")
                completion(.failure(APIError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)))
                return
            }
            
            guard let data = data else {
                completion(.failure(APIError.noData))
                return
            }
            
            do {
                // Try to decode the response directly first
                do {
                    let wrapper = try self.decoder.decode(SessionsResponse.self, from: data)
                    self.logMessage("Retrieved \(wrapper.sessions.count) sessions")
                    completion(.success(wrapper.sessions))
                    return
                } catch {
                    // Fall back to manual JSON parsing if direct decoding fails
                    self.logMessage("Direct decoding failed, trying manual JSON parsing")
                }
                
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let sessionsArray = json["sessions"] as? [[String: Any]] {
                    let sessionsData = try JSONSerialization.data(withJSONObject: sessionsArray, options: [])
                    let sessions = try self.decoder.decode([JITSession].self, from: sessionsData)
                    self.logMessage("Retrieved \(sessions.count) sessions (via manual parsing)")
                    completion(.success(sessions))
                } else {
                    self.logMessage("Failed to extract sessions from response")
                    completion(.failure(APIError.decodingError(details: "Could not extract sessions from response")))
                }
            } catch {
                self.logMessage("Failed to parse device sessions: \(error.localizedDescription)")
                completion(.failure(APIError.decodingError(details: error.localizedDescription)))
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func executeRequest(_ request: URLRequest, retryCount: Int, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            self.removeTask(task)
            
            // Check for network errors that warrant a retry
            if let error = error as NSError?, self.shouldRetry(error: error, statusCode: (response as? HTTPURLResponse)?.statusCode), retryCount < self.retryLimit {
                // Exponential backoff delay
                let delay = self.retryDelay * pow(2.0, Double(retryCount))
                self.logMessage("Request failed, retrying in \(delay) seconds (attempt \(retryCount + 1)/\(self.retryLimit))")
                
                DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                    self.executeRequest(request, retryCount: retryCount + 1, completion: completion)
                }
                return
            }
            
            completion(data, response, error)
        }
        
        addTask(task)
        task.resume()
    }
    
    private func shouldRetry(error: NSError, statusCode: Int?) -> Bool {
        // Retry on network-related errors
        switch error.domain {
        case NSURLErrorDomain:
            switch error.code {
            case NSURLErrorTimedOut, NSURLErrorCannotConnectToHost, NSURLErrorNetworkConnectionLost, 
                 NSURLErrorNotConnectedToInternet, NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
                return true
            default:
                break
            }
        default:
            break
        }
        
        // Retry on certain HTTP status codes
        if let statusCode = statusCode {
            // 408 Request Timeout, 429 Too Many Requests, 500, 502, 503, 504 Server Errors
            return [408, 429, 500, 502, 503, 504].contains(statusCode)
        }
        
        return false
    }
    
    private func logMessage(_ message: String) {
        if loggingEnabled {
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("[\(timestamp)] APIClient: \(message)")
        }
    }
}

// MARK: - Response Types

struct SessionsResponse: Codable {
    let sessions: [JITSession]
}

// MARK: - Error Types

enum APIError: Error, LocalizedError {
    case invalidURL(url: String)
    case invalidResponse
    case serverError(statusCode: Int, message: String)
    case noData
    case decodingError(details: String)
    case encodingError(details: String)
    case serviceError(message: String)
    case networkError(details: String)
    case cancelled
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message)"
        case .noData:
            return "No data received from server"
        case .decodingError(let details):
            return "Error decoding response data: \(details)"
        case .encodingError(let details):
            return "Error encoding request data: \(details)"
        case .serviceError(let message):
            return "Service error: \(message)"
        case .networkError(let details):
            return "Network error: \(details)"
        case .cancelled:
            return "Request was cancelled"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}