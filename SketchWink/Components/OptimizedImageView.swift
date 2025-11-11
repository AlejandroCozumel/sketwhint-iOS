import SwiftUI

/// Optimized image view with automatic thumbnail generation and caching
/// Use for thumbnails to avoid loading full-resolution images
struct OptimizedImageView: View {
    let url: URL?
    let size: CGSize
    let contentMode: ContentMode
    let cornerRadius: CGFloat

    @State private var image: UIImage?
    @State private var isLoading = true

    init(
        url: URL?,
        size: CGSize = CGSize(width: 80, height: 80),
        contentMode: ContentMode = .fill,
        cornerRadius: CGFloat = AppSizing.cornerRadius.sm
    ) {
        self.url = url
        self.size = size
        self.contentMode = contentMode
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if isLoading {
                Rectangle()
                    .fill(AppColors.textSecondary.opacity(0.1))
                    .overlay(
                        ProgressView()
                            .tint(AppColors.primaryBlue)
                    )
            } else {
                Rectangle()
                    .fill(AppColors.textSecondary.opacity(0.1))
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(AppColors.textSecondary)
                    )
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .cornerRadius(cornerRadius)
        .task {
            await loadOptimizedImage()
        }
    }

    /// Load and optimize image for thumbnail display
    private func loadOptimizedImage() async {
        guard let url = url else {
            await MainActor.run {
                isLoading = false
            }
            return
        }

        // Check cache first
        if let cachedImage = ImageCache.shared.get(forKey: url.absoluteString, size: size) {
            await MainActor.run {
                self.image = cachedImage
                self.isLoading = false
            }
            return
        }

        // Load and optimize image
        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            guard let fullImage = UIImage(data: data) else {
                await MainActor.run {
                    isLoading = false
                }
                return
            }

            // Generate optimized thumbnail
            let thumbnail = await generateThumbnail(from: fullImage, targetSize: size)

            // Cache the thumbnail
            ImageCache.shared.set(thumbnail, forKey: url.absoluteString, size: size)

            await MainActor.run {
                self.image = thumbnail
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }

    /// Generate optimized thumbnail with proper sizing and compression
    private func generateThumbnail(from image: UIImage, targetSize: CGSize) async -> UIImage {
        let scale = UIScreen.main.scale

        return await Task.detached(priority: .userInitiated) {
            let format = UIGraphicsImageRendererFormat()
            format.scale = scale
            format.opaque = false

            let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)

            return renderer.image { context in
                // Calculate aspect-fill rect
                let imageSize = image.size
                let widthRatio = targetSize.width / imageSize.width
                let heightRatio = targetSize.height / imageSize.height
                let ratio = max(widthRatio, heightRatio)

                let scaledSize = CGSize(
                    width: imageSize.width * ratio,
                    height: imageSize.height * ratio
                )

                let drawRect = CGRect(
                    x: (targetSize.width - scaledSize.width) / 2,
                    y: (targetSize.height - scaledSize.height) / 2,
                    width: scaledSize.width,
                    height: scaledSize.height
                )

                image.draw(in: drawRect)
            }
        }.value
    }
}

/// Simple in-memory image cache with size-based keys
class ImageCache {
    static let shared = ImageCache()

    private var cache: [String: UIImage] = [:]
    private let queue = DispatchQueue(label: "com.sketchwink.imagecache")
    private let maxCacheSize = 50 // Maximum number of cached images

    private init() {}

    /// Get cached image for URL and size
    func get(forKey key: String, size: CGSize) -> UIImage? {
        let cacheKey = "\(key)_\(Int(size.width))x\(Int(size.height))"
        return queue.sync {
            return cache[cacheKey]
        }
    }

    /// Store image in cache
    func set(_ image: UIImage, forKey key: String, size: CGSize) {
        let cacheKey = "\(key)_\(Int(size.width))x\(Int(size.height))"
        queue.async { [weak self] in
            guard let self = self else { return }

            // Simple LRU: remove oldest if cache is full
            if self.cache.count >= self.maxCacheSize {
                self.cache.removeValue(forKey: self.cache.keys.first ?? "")
            }

            self.cache[cacheKey] = image
        }
    }

    /// Clear entire cache
    func clear() {
        queue.async { [weak self] in
            self?.cache.removeAll()
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: AppSpacing.md) {
        // Thumbnail size
        OptimizedImageView(
            url: URL(string: "https://example.com/image.jpg"),
            size: CGSize(width: 80, height: 80),
            contentMode: .fill
        )

        // Medium size
        OptimizedImageView(
            url: URL(string: "https://example.com/image.jpg"),
            size: CGSize(width: 200, height: 200),
            contentMode: .fit
        )
    }
    .padding()
}
