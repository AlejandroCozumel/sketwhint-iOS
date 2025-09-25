import UIKit

extension UIImage {
    
    // MARK: - Base64 Conversion
    
    /// Converts the image to a base64 string with data URI format
    /// - Parameter quality: JPEG compression quality (0.0 to 1.0, default 0.7)
    /// - Returns: Base64 string with data URI format or nil if conversion fails
    func toBase64String(quality: CGFloat = 0.7) -> String? {
        guard let imageData = self.jpegData(compressionQuality: quality) else {
            print("❌ UIImage+Extensions: Failed to convert image to JPEG data")
            return nil
        }
        
        let base64String = imageData.base64EncodedString()
        let dataUri = "data:image/jpeg;base64,\(base64String)"
        
        print("✅ UIImage+Extensions: Image converted to base64 (quality: \(quality))")
        print("📊 UIImage+Extensions: Original size: \(self.size), Data size: \(imageData.count) bytes")
        
        return dataUri
    }
    
    // MARK: - Image Compression & Resizing
    
    /// Compresses and resizes the image for upload
    /// - Parameters:
    ///   - maxSize: Maximum width or height (default 1024)
    ///   - quality: JPEG compression quality (default 0.7)
    /// - Returns: Processed image ready for upload
    func processForUpload(maxSize: CGFloat = 1024, quality: CGFloat = 0.7) -> UIImage {
        print("🔄 UIImage+Extensions: Processing image for upload...")
        print("📐 UIImage+Extensions: Original size: \(self.size)")
        
        // Step 1: Resize if needed
        let resizedImage = self.resizeIfNeeded(maxSize: maxSize)
        
        // Step 2: Compress
        let compressedImage = resizedImage.compressImage(quality: quality)
        
        print("✅ UIImage+Extensions: Image processed successfully")
        print("📐 UIImage+Extensions: Final size: \(compressedImage.size)")
        
        return compressedImage
    }
    
    /// Resizes the image if it exceeds the maximum size while maintaining aspect ratio
    /// - Parameter maxSize: Maximum width or height
    /// - Returns: Resized image or original if no resizing needed
    private func resizeIfNeeded(maxSize: CGFloat) -> UIImage {
        let size = self.size
        
        // Check if resizing is needed
        if size.width <= maxSize && size.height <= maxSize {
            print("ℹ️ UIImage+Extensions: No resizing needed")
            return self
        }
        
        // Calculate scale to maintain aspect ratio
        let scale = min(maxSize / size.width, maxSize / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        print("🔄 UIImage+Extensions: Resizing from \(size) to \(newSize)")
        
        // Create resized image with scale 1.0 to prevent size multiplication
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0  // Force scale to 1.0
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resizedImage = renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        return resizedImage
    }
    
    /// Compresses the image with specified quality
    /// - Parameter quality: JPEG compression quality (0.0 to 1.0)
    /// - Returns: Compressed image
    private func compressImage(quality: CGFloat) -> UIImage {
        guard let compressedData = self.jpegData(compressionQuality: quality),
              let compressedImage = UIImage(data: compressedData) else {
            print("⚠️ UIImage+Extensions: Compression failed, returning original")
            return self
        }
        
        print("🗜️ UIImage+Extensions: Compressed to \(compressedData.count) bytes (quality: \(quality))")
        return compressedImage
    }
    
    // MARK: - Utility Methods
    
    /// Estimates the file size after JPEG compression
    /// - Parameter quality: JPEG compression quality
    /// - Returns: Estimated file size in bytes
    func estimatedFileSize(quality: CGFloat = 0.7) -> Int {
        guard let data = self.jpegData(compressionQuality: quality) else {
            return 0
        }
        return data.count
    }
    
    /// Checks if the image meets upload requirements
    /// - Parameters:
    ///   - maxSize: Maximum dimension allowed
    ///   - maxFileSize: Maximum file size in bytes
    ///   - quality: JPEG quality for size estimation
    /// - Returns: Tuple indicating if valid and reason if not
    func validateForUpload(maxSize: CGFloat = 1024, maxFileSize: Int = 2_097_152, quality: CGFloat = 0.7) -> (isValid: Bool, reason: String?) {
        // Check dimensions
        if size.width > maxSize || size.height > maxSize {
            return (false, "Image dimensions exceed \(maxSize)px maximum")
        }
        
        // Check estimated file size (2MB default)
        let estimatedSize = estimatedFileSize(quality: quality)
        if estimatedSize > maxFileSize {
            let maxMB = Double(maxFileSize) / 1_048_576
            let estimatedMB = Double(estimatedSize) / 1_048_576
            return (false, "Image size (\(String(format: "%.1f", estimatedMB))MB) exceeds \(String(format: "%.1f", maxMB))MB limit")
        }
        
        return (true, nil)
    }
    
    /// Creates a thumbnail version of the image
    /// - Parameter size: Thumbnail size (square)
    /// - Returns: Thumbnail image
    func createThumbnail(size: CGFloat = 150) -> UIImage {
        let thumbnailSize = CGSize(width: size, height: size)
        
        let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: thumbnailSize))
        }
    }
}

// MARK: - Error Handling for Image Processing

enum ImageProcessingError: LocalizedError {
    case conversionFailed
    case compressionFailed
    case invalidFormat
    case fileTooLarge(currentSize: Int, maxSize: Int)
    case dimensionsTooLarge(currentDimensions: CGSize, maxSize: CGFloat)
    
    var errorDescription: String? {
        switch self {
        case .conversionFailed:
            return "Failed to convert image to base64 format"
        case .compressionFailed:
            return "Failed to compress image"
        case .invalidFormat:
            return "Invalid image format"
        case .fileTooLarge(let currentSize, let maxSize):
            let currentMB = Double(currentSize) / 1_048_576
            let maxMB = Double(maxSize) / 1_048_576
            return "Image file size (\(String(format: "%.1f", currentMB))MB) exceeds maximum allowed size (\(String(format: "%.1f", maxMB))MB)"
        case .dimensionsTooLarge(let currentDimensions, let maxSize):
            return "Image dimensions (\(Int(currentDimensions.width))x\(Int(currentDimensions.height))) exceed maximum allowed size (\(Int(maxSize))x\(Int(maxSize)))"
        }
    }
}

// MARK: - Safe Image Processing

extension UIImage {
    
    /// Safely processes an image for upload with error handling
    /// - Parameters:
    ///   - maxSize: Maximum dimension
    ///   - quality: JPEG quality
    ///   - maxFileSize: Maximum file size in bytes
    /// - Returns: Result with processed image or error
    func safeProcessForUpload(maxSize: CGFloat = 1024, quality: CGFloat = 0.7, maxFileSize: Int = 2_097_152) -> Result<UIImage, ImageProcessingError> {
        
        // Validate original image
        let validation = validateForUpload(maxSize: maxSize, maxFileSize: maxFileSize, quality: quality)
        
        // Process image
        let processedImage = self.processForUpload(maxSize: maxSize, quality: quality)
        
        // Validate processed image
        let processedValidation = processedImage.validateForUpload(maxSize: maxSize, maxFileSize: maxFileSize, quality: quality)
        if !processedValidation.isValid {
            if let reason = processedValidation.reason {
                if reason.contains("dimensions") {
                    return .failure(.dimensionsTooLarge(currentDimensions: processedImage.size, maxSize: maxSize))
                } else {
                    let estimatedSize = processedImage.estimatedFileSize(quality: quality)
                    return .failure(.fileTooLarge(currentSize: estimatedSize, maxSize: maxFileSize))
                }
            }
            return .failure(.compressionFailed)
        }
        
        return .success(processedImage)
    }
    
    /// Safely converts image to base64 with error handling
    /// - Parameter quality: JPEG compression quality
    /// - Returns: Result with base64 string or error
    func safeToBase64String(quality: CGFloat = 0.7) -> Result<String, ImageProcessingError> {
        guard let base64String = self.toBase64String(quality: quality) else {
            return .failure(.conversionFailed)
        }
        return .success(base64String)
    }
}