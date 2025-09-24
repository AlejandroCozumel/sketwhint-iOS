import SwiftUI
import UIKit

struct ImagePreviewView: View {
    let selectedImage: UIImage
    let selectedCategory: CategoryWithOptions
    let selectedOption: GenerationOption
    let onConfirm: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var isProcessing = false
    @State private var processedImage: UIImage?
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundLight
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        // Header
                        VStack(spacing: AppSpacing.sm) {
                            Text("Photo Preview")
                                .headlineLarge()
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text("This photo will be converted into a \(selectedCategory.category.name.lowercased()) with \(selectedOption.displayName.lowercased()) style")
                                .bodyMedium()
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, AppSpacing.lg)
                        }
                        .padding(.top, AppSpacing.md)
                        
                        // Image Preview Card
                        VStack(spacing: AppSpacing.md) {
                            // Image Display
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(AppColors.surfaceLight)
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(AppColors.borderLight, lineWidth: 2)
                                    )
                                
                                if let processedImage = processedImage {
                                    Image(uiImage: processedImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                } else {
                                    Image(uiImage: selectedImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .overlay(
                                            isProcessing ? 
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 14)
                                                    .fill(.black.opacity(0.3))
                                                
                                                VStack(spacing: AppSpacing.sm) {
                                                    ProgressView()
                                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                        .scaleEffect(1.2)
                                                    
                                                    Text("Processing...")
                                                        .captionLarge()
                                                        .foregroundColor(.white)
                                                }
                                            } : nil
                                        )
                                }
                            }
                            .padding(.horizontal, AppSpacing.lg)
                            
                            // Image Info
                            VStack(spacing: AppSpacing.xs) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Category")
                                            .captionLarge()
                                            .foregroundColor(AppColors.textSecondary)
                                        
                                        Text(selectedCategory.category.name)
                                            .bodyMedium()
                                            .foregroundColor(AppColors.textPrimary)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("Style")
                                            .captionLarge()
                                            .foregroundColor(AppColors.textSecondary)
                                        
                                        Text(selectedOption.displayName)
                                            .bodyMedium()
                                            .foregroundColor(AppColors.textPrimary)
                                    }
                                }
                                .padding(.horizontal, AppSpacing.lg)
                                
                                Divider()
                                    .padding(.horizontal, AppSpacing.lg)
                                
                                // Image Details
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Resolution")
                                            .captionLarge()
                                            .foregroundColor(AppColors.textSecondary)
                                        
                                        Text("\(Int(selectedImage.size.width)) × \(Int(selectedImage.size.height))")
                                            .bodyMedium()
                                            .foregroundColor(AppColors.textPrimary)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("Format")
                                            .captionLarge()
                                            .foregroundColor(AppColors.textSecondary)
                                        
                                        Text("JPEG")
                                            .bodyMedium()
                                            .foregroundColor(AppColors.textPrimary)
                                    }
                                }
                                .padding(.horizontal, AppSpacing.lg)
                            }
                            .cardStyle()
                            .padding(.horizontal, AppSpacing.lg)
                        }
                        
                        Spacer(minLength: AppSpacing.xl)
                        
                        // Action Buttons
                        VStack(spacing: AppSpacing.md) {
                            // Confirm Button
                            Button(action: {
                                let imageToUse = processedImage ?? selectedImage
                                onConfirm(imageToUse)
                                dismiss()
                            }) {
                                HStack(spacing: AppSpacing.sm) {
                                    if !isProcessing {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18))
                                    }
                                    
                                    Text("Use This Photo")
                                        .titleMedium()
                                }
                            }
                            .largeButtonStyle(backgroundColor: AppColors.primaryBlue)
                            .disabled(isProcessing)
                            .opacity(isProcessing ? 0.6 : 1.0)
                            .childSafeTouchTarget()
                            
                            // Cancel Button
                            Button("Choose Different Photo") {
                                dismiss()
                            }
                            .buttonStyle(
                                backgroundColor: AppColors.backgroundLight,
                                foregroundColor: AppColors.textSecondary
                            )
                            .childSafeTouchTarget()
                        }
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.bottom, AppSpacing.xl)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .onAppear {
            processImageIfNeeded()
        }
    }
    
    // MARK: - Image Processing
    private func processImageIfNeeded() {
        guard processedImage == nil else { return }
        
        isProcessing = true
        
        // Process image in background
        DispatchQueue.global(qos: .userInitiated).async {
            let processed = self.processImageForUpload(selectedImage)
            
            DispatchQueue.main.async {
                self.processedImage = processed
                self.isProcessing = false
            }
        }
    }
    
    private func processImageForUpload(_ image: UIImage) -> UIImage {
        // Resize to maximum 1024x1024 while maintaining aspect ratio
        let maxSize: CGFloat = 1024
        let size = image.size
        
        if size.width <= maxSize && size.height <= maxSize {
            return image // No resizing needed
        }
        
        let scale = min(maxSize / size.width, maxSize / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
}

// MARK: - Preview
struct ImagePreviewView_Previews: PreviewProvider {
    static var previews: some View {
        ImagePreviewView(
            selectedImage: UIImage(systemName: "photo") ?? UIImage(),
            selectedCategory: CategoryWithOptions(
                category: GenerationCategory(
                    id: "coloring_pages",
                    name: "Coloring Pages",
                    description: "Fun coloring pages",
                    icon: "🎨",
                    imageUrl: nil,
                    color: "#F97316",
                    tokenCost: 1,
                    multipleOptions: true,
                    maxOptionsCount: 4,
                    isActive: true,
                    isDefault: true,
                    sortOrder: 1
                ),
                options: []
            ),
            selectedOption: GenerationOption(
                id: "cartoon_style",
                categoryId: "coloring_pages",
                name: "Cartoon Style",
                description: "Cute cartoon style",
                promptTemplate: "cartoon style",
                style: "cartoon",
                imageUrl: nil,
                color: nil,
                isActive: true,
                isDefault: true,
                sortOrder: 1
            ),
            onConfirm: { _ in }
        )
    }
}