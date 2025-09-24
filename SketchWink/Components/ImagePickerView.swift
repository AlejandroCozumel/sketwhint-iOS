import SwiftUI
import UIKit
import PhotosUI
import Photos
import AVFoundation

struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    let sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false // We'll handle cropping in preview
        picker.modalPresentationStyle = .fullScreen
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Photo Source Selection Sheet
struct PhotoSourceSelectionView: View {
    @Binding var showingImagePicker: Bool
    @Binding var showingCamera: Bool
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: AppSpacing.lg) {
                // Header
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.primaryBlue)
                    
                    Text("Add Photo")
                        .headlineLarge()
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("Choose how you'd like to add a photo to convert into a coloring page")
                        .bodyMedium()
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.lg)
                }
                .padding(.top, AppSpacing.xl)
                
                Spacer()
                
                // Photo Source Options
                VStack(spacing: AppSpacing.md) {
                    // Camera Button
                    Button(action: {
                        requestCameraPermission { granted in
                            if granted {
                                showingCamera = true
                                dismiss()
                            }
                        }
                    }) {
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 24))
                                .foregroundColor(AppColors.primaryBlue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Take Photo")
                                    .titleMedium()
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Text("Use your camera to capture a new photo")
                                    .captionLarge()
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.backgroundLight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.borderLight, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .childSafeTouchTarget()
                    
                    // Gallery Button
                    Button(action: {
                        requestPhotoLibraryPermission { granted in
                            if granted {
                                showingImagePicker = true
                                dismiss()
                            }
                        }
                    }) {
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 24))
                                .foregroundColor(AppColors.primaryPurple)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Choose from Gallery")
                                    .titleMedium()
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Text("Select an existing photo from your library")
                                    .captionLarge()
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.backgroundLight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.borderLight, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .childSafeTouchTarget()
                }
                .padding(.horizontal, AppSpacing.lg)
                
                Spacer()
                
                // Cancel Button
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(
                    backgroundColor: AppColors.backgroundLight,
                    foregroundColor: AppColors.textSecondary
                )
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xl)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerView(
                selectedImage: $selectedImage,
                sourceType: .photoLibrary
            )
        }
        .sheet(isPresented: $showingCamera) {
            ImagePickerView(
                selectedImage: $selectedImage,
                sourceType: .camera
            )
        }
    }
}

// MARK: - Permission Helpers
private func requestCameraPermission(completion: @escaping (Bool) -> Void) {
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    
    switch status {
    case .authorized:
        completion(true)
    case .notDetermined:
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    case .denied, .restricted:
        DispatchQueue.main.async {
            // Show alert to go to settings
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
            completion(false)
        }
    @unknown default:
        completion(false)
    }
}

private func requestPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    
    switch status {
    case .authorized, .limited:
        completion(true)
    case .notDetermined:
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
            DispatchQueue.main.async {
                completion(newStatus == .authorized || newStatus == .limited)
            }
        }
    case .denied, .restricted:
        DispatchQueue.main.async {
            // Show alert to go to settings
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl)
            }
            completion(false)
        }
    @unknown default:
        completion(false)
    }
}

// MARK: - Preview
struct PhotoSourceSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        PhotoSourceSelectionView(
            showingImagePicker: .constant(false),
            showingCamera: .constant(false),
            selectedImage: .constant(nil)
        )
    }
}