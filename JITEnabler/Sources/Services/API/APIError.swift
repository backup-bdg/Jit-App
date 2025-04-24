import Foundation

// MARK: - API Errors
enum APIError: Error, LocalizedError {
    case invalidURL(url: String)
    case encodingError(details: String)
    case decodingError(details: String)
    case connectionError(details: String)
    case authenticationError
    case serverError(code: Int)
    case responseError(details: String)
    case dataError
    case timeout
    case unknownError(error: Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .encodingError(let details):
            return "Failed to encode request parameters: \(details)"
        case .decodingError(let details):
            return "Failed to decode response: \(details)"
        case .connectionError(let details):
            return "Connection error: \(details)"
        case .authenticationError:
            return "Authentication failed"
        case .serverError(let code):
            return "Server error with code: \(code)"
        case .responseError(let details):
            return "Response error: \(details)"
        case .dataError:
            return "Invalid data received from server"
        case .timeout:
            return "Request timed out"
        case .unknownError(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}
