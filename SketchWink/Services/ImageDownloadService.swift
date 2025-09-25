import Foundation
import UIKit
import Photos

/// Service for downloading and converting images with different formats
class ImageDownloadService {
    static let shared = ImageDownloadService()
    private let session = URLSession.shared
    private let baseURL = AppConfig.API.baseURL
    
    private init() {}
    
    /// Download image with format conversion
    func downloadImage(
        imageId: String,
        format: ImageFormat = .jpg,
        quality: Int = 90,
        authToken: String
    ) async throws -> Data {
        
        // Build URL with query parameters
        var components = URLComponents(string: "\(baseURL)/images/\(imageId)/download")!
        components.queryItems = [
            URLQueryItem(name: "format", value: format.rawValue),
            URLQueryItem(name: "quality", value: String(quality))
        ]
        
        guard let url = components.url else {
            throw ImageDownloadError.invalidURL
        }
        
        // Create request with auth header
        var request = URLRequest(url: url)
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "GET"
        
        #if DEBUG
        print("📥 ImageDownloadService: Downloading image")
        print("   - Image ID: \(imageId)")
        print("   - Format: \(format.rawValue)")
        print("   - Quality: \(quality)%")
        print("   - URL: \(url)")
        #endif
        
        // Perform download
        let (data, response) = try await session.data(for: request)
        
        // Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImageDownloadError.invalidResponse
        }
        
        #if DEBUG
        print("📥 ImageDownloadService: Response received")
        print("   - Status Code: \(httpResponse.statusCode)")
        print("   - Data Size: \(data.count) bytes")
        #endif
        
        switch httpResponse.statusCode {
        case 200:
            return data
        case 404:
            throw ImageDownloadError.imageNotFound
        case 401:
            throw ImageDownloadError.unauthorized
        case 500:
            throw ImageDownloadError.serverError
        default:
            throw ImageDownloadError.unknownError(httpResponse.statusCode)
        }
    }
    
    /// Save image to Photos Library (for images only, not PDFs)
    func saveImageToPhotos(_ data: Data, format: ImageFormat) async throws {
        guard format != .pdf else {
            throw ImageDownloadError.cannotSaveToPhotos
        }
        
        guard let image = UIImage(data: data) else {
            throw ImageDownloadError.invalidImageData
        }
        
        // Request photo library permission (using same level as photo picker)
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        
        guard status == .authorized else {
            throw ImageDownloadError.permissionDenied
        }
        
        // Save to photo library
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
        
        #if DEBUG
        print("📸 ImageDownloadService: Image saved to Photos")
        print("   - Format: \(format.rawValue)")
        print("   - Data Size: \(data.count) bytes")
        #endif
    }
    
    /// Save to Files (for PDFs and other formats)
    func saveToFiles(_ data: Data, filename: String) throws -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(filename)
        
        try data.write(to: fileURL)
        
        #if DEBUG
        print("📁 ImageDownloadService: File saved to Documents")
        print("   - Filename: \(filename)")
        print("   - Path: \(fileURL.path)")
        print("   - Data Size: \(data.count) bytes")
        #endif
        
        return fileURL
    }
    
    /// Create appropriate filename for the image
    func createFilename(imageId: String, format: ImageFormat, originalTitle: String?) -> String {
        // Clean the title for use as filename
        let cleanTitle: String
        if let title = originalTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            // Remove invalid filename characters and limit length
            cleanTitle = title
                .replacingOccurrences(of: "[^a-zA-Z0-9\\s\\-_]", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: "_", options: .regularExpression)
                .prefix(30)
                .trimmingCharacters(in: CharacterSet(charactersIn: "_-"))
                .lowercased()
        } else {
            cleanTitle = "sketchwink_creation"
        }
        
        // Ensure we have a valid filename
        let finalName = cleanTitle.isEmpty ? "sketchwink_creation" : cleanTitle
        return "\(finalName)_\(imageId.prefix(8)).\(format.fileExtension)"
    }
}

// MARK: - Image Format Definition
extension ImageDownloadService {
    enum ImageFormat: String, CaseIterable {
        case jpg = "jpg"
        case png = "png"
        case webp = "webp"
        case pdf = "pdf"
        
        var contentType: String {
            switch self {
            case .jpg: return "image/jpeg"
            case .png: return "image/png"
            case .webp: return "image/webp"
            case .pdf: return "application/pdf"
            }
        }
        
        var fileExtension: String {
            return self.rawValue
        }
        
        var displayName: String {
            switch self {
            case .jpg: return "JPEG"
            case .png: return "PNG"
            case .webp: return "WebP"
            case .pdf: return "PDF"
            }
        }
        
        var description: String {
            switch self {
            case .jpg: return "Compressed format, smaller file size"
            case .png: return "High quality, supports transparency"
            case .webp: return "Modern format, good compression"
            case .pdf: return "Perfect for printing, vector format"
            }
        }
    }
}

// MARK: - Download Errors
enum ImageDownloadError: LocalizedError {
    case invalidURL
    case invalidResponse
    case imageNotFound
    case unauthorized
    case serverError
    case unknownError(Int)
    case cannotSaveToPhotos
    case invalidImageData
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid download URL"
        case .invalidResponse:
            return "Invalid server response"
        case .imageNotFound:
            return "Image not found or access denied"
        case .unauthorized:
            return "Authentication required"
        case .serverError:
            return "Server error occurred"
        case .unknownError(let code):
            return "Unknown error (Code: \(code))"
        case .cannotSaveToPhotos:
            return "Cannot save PDF to Photos library"
        case .invalidImageData:
            return "Invalid image data received"
        case .permissionDenied:
            return "Photo library permission denied"
        }
    }
    
    var userFriendlyMessage: String {
        switch self {
        case .invalidURL, .invalidResponse, .unknownError:
            return "Something went wrong. Please try again."
        case .imageNotFound:
            return "This image is no longer available."
        case .unauthorized:
            return "Please sign in again to download images."
        case .serverError:
            return "Our servers are having issues. Please try again later."
        case .cannotSaveToPhotos:
            return "PDFs can only be shared, not saved to Photos."
        case .invalidImageData:
            return "This image file is corrupted. Please try a different format."
        case .permissionDenied:
            return "Please allow access to Photos in Settings to save images."
        }
    }
}