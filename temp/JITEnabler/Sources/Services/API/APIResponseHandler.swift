import Foundation

// MARK: - API Response Handling
class APIResponseHandler {
    private let decoder = JSONDecoder()
    private let responseQueue = DispatchQueue.main
    
    init() {
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }
    
    // Generic response handling for any type
    func handleResponse<T: Decodable>(
        data: Data?, 
        response: URLResponse?, 
        error: Error?, 
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        // Handle network errors
        if let error = error {
            responseQueue.async {
                completion(.failure(APIError.connectionError(details: error.localizedDescription)))
            }
            return
        }
        
        // Verify we have data and response
        guard let data = data else {
            responseQueue.async {
                completion(.failure(APIError.dataError))
            }
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            responseQueue.async {
                completion(.failure(APIError.responseError(details: "Invalid response type")))
            }
            return
        }
        
        // Handle HTTP status codes
        switch httpResponse.statusCode {
        case 200...299:
            // Success - decode the data
            do {
                let decodedObject = try decoder.decode(T.self, from: data)
                responseQueue.async {
                    completion(.success(decodedObject))
                }
            } catch {
                responseQueue.async {
                    completion(.failure(APIError.decodingError(details: error.localizedDescription)))
                }
            }
            
        case 401:
            responseQueue.async {
                completion(.failure(APIError.authenticationError))
            }
            
        case 400...499:
            // Client error
            responseQueue.async {
                completion(.failure(APIError.responseError(details: "Client error with status code: \(httpResponse.statusCode)")))
            }
            
        case 500...599:
            // Server error
            responseQueue.async {
                completion(.failure(APIError.serverError(code: httpResponse.statusCode)))
            }
            
        default:
            // Unexpected status code
            responseQueue.async {
                completion(.failure(APIError.responseError(details: "Unexpected status code: \(httpResponse.statusCode)")))
            }
        }
    }
    
    // String response handler for token and simple responses
    func handleStringResponse(
        data: Data?, 
        response: URLResponse?, 
        error: Error?,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // Handle network errors
        if let error = error {
            responseQueue.async {
                completion(.failure(APIError.connectionError(details: error.localizedDescription)))
            }
            return
        }
        
        // Verify we have data and response
        guard let data = data else {
            responseQueue.async {
                completion(.failure(APIError.dataError))
            }
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            responseQueue.async {
                completion(.failure(APIError.responseError(details: "Invalid response type")))
            }
            return
        }
        
        // Handle HTTP status codes
        switch httpResponse.statusCode {
        case 200...299:
            // Success - extract string from data
            if let token = String(data: data, encoding: .utf8) {
                responseQueue.async {
                    completion(.success(token))
                }
            } else {
                responseQueue.async {
                    completion(.failure(APIError.decodingError(details: "Could not decode response as string")))
                }
            }
            
        case 401:
            responseQueue.async {
                completion(.failure(APIError.authenticationError))
            }
            
        case 400...499:
            // Client error
            responseQueue.async {
                completion(.failure(APIError.responseError(details: "Client error with status code: \(httpResponse.statusCode)")))
            }
            
        case 500...599:
            // Server error
            responseQueue.async {
                completion(.failure(APIError.serverError(code: httpResponse.statusCode)))
            }
            
        default:
            // Unexpected status code
            responseQueue.async {
                completion(.failure(APIError.responseError(details: "Unexpected status code: \(httpResponse.statusCode)")))
            }
        }
    }
}
