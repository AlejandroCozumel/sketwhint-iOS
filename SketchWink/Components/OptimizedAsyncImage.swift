import SwiftUI
import UIKit

/// Optimized AsyncImage for gallery thumbnails - reduces 1MB images to ~200KB
/// Use regular AsyncImage for full-size detail views
struct OptimizedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let thumbnailSize: CGFloat
    let quality: CGFloat
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    
    @State private var uiImage: UIImage?
    @State private var isLoading = false
    @State private var error: Error?
    
    init(
        url: URL?,
        thumbnailSize: CGFloat = 160, // Gallery card height
        quality: CGFloat = 0.6,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.thumbnailSize = thumbnailSize
        self.quality = quality
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let uiImage = uiImage {
                content(Image(uiImage: uiImage))
            } else if isLoading {
                placeholder()
            } else {
                placeholder()
                    .onAppear {
                        loadOptimizedThumbnail()
                    }
            }
        }
        .onChange(of: url) {
            uiImage = nil
            loadOptimizedThumbnail()
        }
    }
    
    private func loadOptimizedThumbnail() {
        guard let url = url else { return }
        
        isLoading = true
        
        // Check thumbnail cache first
        if let cachedThumbnail = ThumbnailCache.shared.thumbnail(for: url.absoluteString) {
            self.uiImage = cachedThumbnail
            self.isLoading = false
            return
        }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                
                guard let originalImage = UIImage(data: data) else {
                    await MainActor.run {
                        self.isLoading = false
                        self.error = ThumbnailError.invalidImageData
                    }
                    return
                }
                
                // Create optimized thumbnail
                let thumbnail = await createOptimizedThumbnail(from: originalImage)
                
                await MainActor.run {
                    self.uiImage = thumbnail
                    self.isLoading = false
                    
                    // Cache thumbnail for reuse
                    ThumbnailCache.shared.setThumbnail(thumbnail, for: url.absoluteString)
                    
                    #if DEBUG
                    let originalSize = data.count
                    let thumbnailSize = thumbnail.estimatedFileSize(quality: quality)
                    let reduction = (1.0 - Double(thumbnailSize) / Double(originalSize)) * 100
                    print("🖼️ OptimizedAsyncImage: \(originalSize/1024)KB → \(thumbnailSize/1024)KB (\(Int(reduction))% reduction)")
                    #endif
                }
                
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
    
    private func createOptimizedThumbnail(from image: UIImage) async -> UIImage {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Resize to thumbnail dimensions (much smaller than original)
                let thumbnail = image.processForUpload(maxSize: thumbnailSize, quality: quality)
                continuation.resume(returning: thumbnail)
            }
        }
    }
}

// MARK: - Convenience Initializers for Gallery Use
// Use the main OptimizedAsyncImage initializer directly in views

// MARK: - Dedicated Thumbnail Cache (Separate from full images)

class ThumbnailCache {
    static let shared = ThumbnailCache()
    
    private let cache = NSCache<NSString, UIImage>()
    private let maxThumbnails = 200 // Cache up to 200 thumbnails
    
    private init() {
        cache.countLimit = maxThumbnails
        
        // Clear cache on memory warning
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        #if DEBUG
        print("🗂️ ThumbnailCache: Initialized with limit of \(maxThumbnails) thumbnails")
        #endif
    }
    
    func thumbnail(for key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func setThumbnail(_ image: UIImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
    
    @objc private func clearCache() {
        cache.removeAllObjects()
        #if DEBUG
        print("🧹 ThumbnailCache: Cleared cache due to memory warning")
        #endif
    }
    
    func clearAll() {
        cache.removeAllObjects()
    }
}

// MARK: - Error Handling

enum ThumbnailError: LocalizedError {
    case invalidImageData
    case optimizationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Invalid image data received"
        case .optimizationFailed:
            return "Failed to create thumbnail"
        }
    }
}