import SwiftUI

struct FolderPickerView: View {
    let selectedImages: [String] // Image IDs to move
    let onFolderSelected: (UserFolder) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var folderService = FolderService.shared
    
    @State private var searchText = ""
    @State private var showingCreateFolder = false
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    private var filteredFolders: [UserFolder] {
        var folders = folderService.folders
        
        if !searchText.isEmpty {
            folders = folders.filter { folder in
                folder.name.localizedCaseInsensitiveContains(searchText) ||
                (folder.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        return folders.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with search
                headerSection
                
                // Content
                if isLoading {
                    loadingView
                } else if folderService.folders.isEmpty {
                    emptyStateView
                } else if filteredFolders.isEmpty {
                    noResultsView
                } else {
                    folderListView
                }
                
                Spacer()
            }
            .background(AppColors.backgroundLight)
            .navigationTitle("Choose Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.primaryBlue)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateFolder = true }) {
                        Image(systemName: "plus")
                            .font(AppTypography.titleMedium)
                            .foregroundColor(AppColors.primaryBlue)
                    }
                    .childSafeTouchTarget()
                }
            }
            .task {
                await loadFolders()
            }
            .sheet(isPresented: $showingCreateFolder) {
                CreateFolderView()
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: AppSpacing.sm) {
            // Move info
            HStack {
                Image(systemName: "arrow.right.to.line")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.primaryBlue)
                
                Text("Moving \(selectedImages.count) image\(selectedImages.count == 1 ? "" : "s")")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
            }
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.textSecondary)
                    .font(.system(size: 16))
                
                TextField("Search folders...", text: $searchText)
                    .font(AppTypography.bodyMedium)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.textSecondary)
                            .font(.system(size: 16))
                    }
                    .childSafeTouchTarget()
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColors.surfaceLight)
            .clipShape(Capsule())
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
    }
    
    // MARK: - Folder List View
    private var folderListView: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.xs) {
                ForEach(filteredFolders, id: \.id) { folder in
                    FolderPickerRow(
                        folder: folder,
                        onTap: {
                            onFolderSelected(folder)
                            dismiss()
                        }
                    )
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.xl)
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: AppSpacing.lg) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppColors.primaryBlue)
            
            Text("Loading folders...")
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 50))
                .foregroundColor(AppColors.primaryBlue.opacity(0.6))
            
            VStack(spacing: AppSpacing.sm) {
                Text("No Folders Yet")
                    .font(AppTypography.headlineMedium)
                    .foregroundColor(AppColors.textPrimary)
                
                Text("Create your first folder to organize these images")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }
            
            Button(action: { showingCreateFolder = true }) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("Create Folder")
                        .font(AppTypography.titleMedium)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.primaryBlue)
                .clipShape(Capsule())
            }
            .childSafeTouchTarget()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, AppSpacing.xl)
    }
    
    // MARK: - No Results View
    private var noResultsView: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(AppColors.textSecondary.opacity(0.6))
            
            VStack(spacing: AppSpacing.sm) {
                Text("No Folders Found")
                    .font(AppTypography.headlineMedium)
                    .foregroundColor(AppColors.textPrimary)
                
                Text("Try adjusting your search or create a new folder")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                searchText = ""
            }) {
                Text("Clear Search")
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.primaryBlue)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.primaryBlue.opacity(0.1))
                    .clipShape(Capsule())
            }
            .childSafeTouchTarget()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, AppSpacing.xl)
    }
    
    // MARK: - Methods
    private func loadFolders() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await folderService.loadFolders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Folder Picker Row
struct FolderPickerRow: View {
    let folder: UserFolder
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.md) {
                // Folder icon with color
                ZStack {
                    Circle()
                        .fill(Color(hex: folder.color).opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Text(folder.icon)
                        .font(.system(size: 24))
                }
                
                // Folder info
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(folder.name)
                        .font(AppTypography.titleMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                        
                        Text(folder.formattedImageCount)
                            .font(AppTypography.captionLarge)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    if let description = folder.description, !description.isEmpty {
                        Text(description)
                            .font(AppTypography.captionLarge)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Arrow indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textSecondary.opacity(0.6))
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColors.surfaceLight)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.borderLight, lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .shadow(
                color: AppColors.primaryBlue.opacity(0.1),
                radius: isPressed ? 2 : 4,
                x: 0,
                y: isPressed ? 1 : 2
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0) {
            // Handle press state for better feedback
        } onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }
        .childSafeTouchTarget()
    }
}

#Preview {
    FolderPickerView(
        selectedImages: ["img1", "img2", "img3"],
        onFolderSelected: { folder in
            print("Selected folder: \(folder.name)")
        }
    )
}