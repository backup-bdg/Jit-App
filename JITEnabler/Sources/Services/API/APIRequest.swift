import Foundation

// MARK: - Request Creation
struct APIRequest {
    let url: URL
    let method: HTTPMethod
    let headers: [String: String]
    let parameters: [String: Any]?
    let requiresAuthentication: Bool
    
    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }
    
    init(
        url: URL,
        method: HTTPMethod = .get,
        headers: [String: String] = [:],
        parameters: [String: Any]? = nil,
        requiresAuthentication: Bool = false
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.parameters = parameters
        self.requiresAuthentication = requiresAuthentication
    }
    
    // Convert to URLRequest
    func asURLRequest(token: String? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        // Add default headers
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("JITEnabler/1.0", forHTTPHeaderField: "User-Agent")
        
        // Add custom headers
        for (key, value) in headers {
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        // Add authentication if required and token is available
        if requiresAuthentication, let token = token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add parameters to the request body for POST, PUT methods
        if let parameters = parameters, method == .post || method == .put {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
            } catch {
                // Log error but continue with request
                print("Error serializing parameters: \(error.localizedDescription)")
            }
        }
        
        return request
    }
}
