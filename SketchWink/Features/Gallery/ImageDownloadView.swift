import SwiftUI

struct ImageDownloadView: View {
    let image: GeneratedImage
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedFormat: ImageDownloadService.ImageFormat = .png
    @State private var quality: Double = 90
    @State private var isDownloading = false
    @State private var showingShareSheet = false
    @State private var shareableURL: URL?
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.sectionSpacing) {
                    
                    // Image preview
                    imagePreviewView
                    
                    // Format selection
                    formatSelectionView
                    
                    // Quality slider (disabled for PDF)
                    if selectedFormat != .pdf {
                        qualitySelectionView
                    }
                    
                    // Download button
                    downloadButtonView
                }
                .pageMargins()
                .padding(.vertical, AppSpacing.sectionSpacing)
            }
            .background(AppColors.backgroundLight)
            .navigationTitle("Download Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.primaryBlue)
                }
            }
        }
        .alert("Success!", isPresented: $showingSuccessAlert) {
            Button("OK") { dismiss() }
        } message: {
            Text(successMessage)
        }
        .alert("Download Failed", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingShareSheet) {
            if let shareableURL = shareableURL {
                ActivityViewController(activityItems: [shareableURL])
            }
        }
    }
    
    // MARK: - Image Preview
    private var imagePreviewView: some View {
        VStack(spacing: AppSpacing.md) {
            AsyncImage(url: URL(string: image.imageUrl)) { imagePhase in
                switch imagePhase {
                case .success(let swiftUIImage):
                    swiftUIImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 150)
                        .cornerRadius(AppSizing.cornerRadius.lg)
                case .failure(_), .empty:
                    RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg)
                        .fill(AppColors.textSecondary.opacity(0.1))
                        .frame(height: 150)
                        .overlay(
                            ProgressView()
                                .tint(AppColors.primaryBlue)
                        )
                @unknown default:
                    EmptyView()
                }
            }
            
            Text(image.generation?.title ?? image.originalUserPrompt ?? "SketchWink Creation")
                .font(AppTypography.titleMedium)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
        }
        .cardStyle()
    }
    
    // MARK: - Format Selection
    private var formatSelectionView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Choose Format")
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)
            
            VStack(spacing: AppSpacing.sm) {
                ForEach(ImageDownloadService.ImageFormat.allCases, id: \.self) { format in
                    FormatOptionCard(
                        format: format,
                        isSelected: selectedFormat == format,
                        onSelect: {
                            selectedFormat = format
                        }
                    )
                }
            }
        }
        .cardStyle()
    }
    
    // MARK: - Quality Selection
    private var qualitySelectionView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Image Quality")
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)
            
            VStack(spacing: AppSpacing.md) {
                HStack {
                    Text("Quality: \(Int(quality))%")
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Spacer()
                    
                    Text(qualityDescription)
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Slider(value: $quality, in: 1...100, step: 1)
                    .tint(AppColors.primaryBlue)
                
                HStack {
                    Text("Smaller file")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Spacer()
                    
                    Text("Better quality")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .cardStyle()
    }
    
    // MARK: - Download Button
    private var downloadButtonView: some View {
        Button {
            Task {
                await downloadImage()
            }
        } label: {
            HStack(spacing: AppSpacing.sm) {
                if isDownloading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Text("📥")
                        .font(.system(size: 20))
                }
                
                Text(isDownloading ? "Downloading..." : "Download \(selectedFormat.displayName)")
                    .font(AppTypography.titleMedium)
                    .fontWeight(.semibold)
            }
        }
        .largeButtonStyle(backgroundColor: AppColors.primaryBlue)
        .disabled(isDownloading)
        .childSafeTouchTarget()
    }
    
    // MARK: - Helper Properties
    private var qualityDescription: String {
        switch Int(quality) {
        case 1...30:
            return "Low quality"
        case 31...70:
            return "Good quality"
        case 71...90:
            return "High quality"
        default:
            return "Best quality"
        }
    }
    
    // MARK: - Download Logic
    private func downloadImage() async {
        isDownloading = true
        defer { isDownloading = false }
        
        do {
            // Get auth token
            guard let authToken = try KeychainManager.shared.retrieveToken() else {
                throw ImageDownloadError.unauthorized
            }
            
            // Download image data
            let data = try await ImageDownloadService.shared.downloadImage(
                imageId: image.id,
                format: selectedFormat,
                quality: Int(quality),
                authToken: authToken
            )
            
            // Handle based on format
            if selectedFormat == .pdf {
                // Save PDF to Files and show share sheet
                let filename = ImageDownloadService.shared.createFilename(
                    imageId: image.id,
                    format: selectedFormat,
                    originalTitle: image.generation?.title ?? image.originalUserPrompt
                )
                
                let fileURL = try ImageDownloadService.shared.saveToFiles(data, filename: filename)
                
                await MainActor.run {
                    shareableURL = fileURL
                    showingShareSheet = true
                }
            } else {
                // Save image to Photos
                try await ImageDownloadService.shared.saveImageToPhotos(data, format: selectedFormat)
                
                await MainActor.run {
                    successMessage = "Image saved to Photos! 📸\nFormat: \(selectedFormat.displayName) • Quality: \(Int(quality))%"
                    showingSuccessAlert = true
                }
            }
            
        } catch let error as ImageDownloadError {
            await MainActor.run {
                errorMessage = error.userFriendlyMessage
                showingErrorAlert = true
            }
        } catch {
            await MainActor.run {
                errorMessage = "Something went wrong. Please try again."
                showingErrorAlert = true
            }
        }
    }
}

// MARK: - Format Option Card
struct FormatOptionCard: View {
    let format: ImageDownloadService.ImageFormat
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: AppSpacing.md) {
                // Format icon
                VStack(spacing: AppSpacing.xs) {
                    Text(formatIcon)
                        .font(.system(size: 24))
                    
                    Text(format.displayName)
                        .font(AppTypography.captionLarge)
                        .fontWeight(.medium)
                }
                .frame(width: 60)
                
                // Format details
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack {
                        Text(format.displayName)
                            .font(AppTypography.titleMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
                        
                        Spacer()
                        
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(AppColors.primaryBlue)
                        }
                    }
                    
                    Text(format.description)
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                    .fill(isSelected ? AppColors.primaryBlue.opacity(0.1) : AppColors.surfaceLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                            .stroke(
                                isSelected ? AppColors.primaryBlue : AppColors.borderLight,
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .childSafeTouchTarget()
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }
    
    private var formatIcon: String {
        switch format {
        case .jpg: return "📷"
        case .png: return "🖼️"
        case .webp: return "🌐"
        case .pdf: return "📄"
        }
    }
}