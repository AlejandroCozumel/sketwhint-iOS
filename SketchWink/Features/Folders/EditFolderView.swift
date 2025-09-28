import SwiftUI

struct EditFolderView: View {
    let folder: UserFolder
    @Environment(\.dismiss) private var dismiss
    @StateObject private var folderService = FolderService.shared
    
    @State private var folderName: String
    @State private var folderDescription: String
    @State private var selectedColor: String
    @State private var selectedIcon: String
    @State private var isUpdating = false
    @State private var showingDeleteConfirmation = false
    @State private var errorMessage: String?
    
    init(folder: UserFolder) {
        self.folder = folder
        _folderName = State(initialValue: folder.name)
        _folderDescription = State(initialValue: folder.description ?? "")
        _selectedColor = State(initialValue: folder.color)
        _selectedIcon = State(initialValue: folder.icon)
    }
    
    private var hasChanges: Bool {
        folderName.trimmingCharacters(in: .whitespacesAndNewlines) != folder.name ||
        folderDescription.trimmingCharacters(in: .whitespacesAndNewlines) != (folder.description ?? "") ||
        selectedColor != folder.color ||
        selectedIcon != folder.icon
    }
    
    private var isValidInput: Bool {
        !folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        folderName.count <= FolderConstants.maxNameLength &&
        folderDescription.count <= FolderConstants.maxDescriptionLength
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Preview Section
                    previewSection
                    
                    // Name Section
                    nameSection
                    
                    // Description Section
                    descriptionSection
                    
                    // Icon Selection
                    iconSelectionSection
                    
                    // Color Selection
                    colorSelectionSection
                    
                    // Action Buttons
                    actionButtonsSection
                    
                    Spacer(minLength: AppSpacing.xl)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.lg)
            }
            .background(AppColors.backgroundLight)
            .navigationTitle("Edit Folder")
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
                    Button("Save") {
                        Task { await updateFolder() }
                    }
                    .font(AppTypography.titleMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(hasChanges && isValidInput ? AppColors.primaryBlue : AppColors.textSecondary)
                    .disabled(!hasChanges || !isValidInput || isUpdating)
                }
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
            .alert("Delete Folder", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task { await deleteFolder() }
                }
            } message: {
                Text("Are you sure you want to delete '\(folder.name)'? This action cannot be undone. Images in this folder will return to your main gallery.")
            }
        }
    }
    
    // MARK: - Preview Section
    private var previewSection: some View {
        VStack(spacing: AppSpacing.md) {
            Text("Preview")
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Folder preview card
            VStack(spacing: 0) {
                // Icon section
                ZStack {
                    Color(hex: selectedColor)
                        .opacity(0.15)
                    
                    Text(selectedIcon)
                        .font(.system(size: 40))
                }
                .frame(height: 120)
                
                // Info section
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack {
                        Text(folderName.isEmpty ? "Folder Name" : folderName)
                            .font(AppTypography.titleMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(folderName.isEmpty ? AppColors.textSecondary : AppColors.textPrimary)
                            .lineLimit(1)
                        
                        Spacer()
                    }
                    
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                        
                        Text(folder.formattedImageCount)
                            .font(AppTypography.captionLarge)
                            .foregroundColor(AppColors.textSecondary)
                        
                        Spacer()
                    }
                    
                    if !folderDescription.isEmpty {
                        Text(folderDescription)
                            .font(AppTypography.captionLarge)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
            }
            .frame(width: 200)
            .background(AppColors.surfaceLight)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.borderLight, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Name Section
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("Folder Name")
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.textPrimary)
                
                Text("*")
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.errorRed)
                
                Spacer()
                
                Text("\(folderName.count)/\(FolderConstants.maxNameLength)")
                    .font(AppTypography.captionLarge)
                    .foregroundColor(folderName.count > FolderConstants.maxNameLength ? AppColors.errorRed : AppColors.textSecondary)
            }
            
            TextField("Enter folder name", text: $folderName)
                .font(AppTypography.bodyMedium)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(AppColors.surfaceLight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            folderName.count > FolderConstants.maxNameLength ? AppColors.errorRed : AppColors.borderLight,
                            lineWidth: 1
                        )
                )
        }
    }
    
    // MARK: - Description Section
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("Description")
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.textPrimary)
                
                Text("(Optional)")
                    .font(AppTypography.captionLarge)
                    .foregroundColor(AppColors.textSecondary)
                
                Spacer()
                
                Text("\(folderDescription.count)/\(FolderConstants.maxDescriptionLength)")
                    .font(AppTypography.captionLarge)
                    .foregroundColor(folderDescription.count > FolderConstants.maxDescriptionLength ? AppColors.errorRed : AppColors.textSecondary)
            }
            
            TextField("Enter description", text: $folderDescription, axis: .vertical)
                .font(AppTypography.bodyMedium)
                .lineLimit(3...6)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(AppColors.surfaceLight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            folderDescription.count > FolderConstants.maxDescriptionLength ? AppColors.errorRed : AppColors.borderLight,
                            lineWidth: 1
                        )
                )
        }
    }
    
    // MARK: - Icon Selection
    private var iconSelectionSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Icon")
                .font(AppTypography.titleMedium)
                .foregroundColor(AppColors.textPrimary)
            
            LazyVGrid(columns: GridLayouts.iconGrid, spacing: AppSpacing.sm) {
                ForEach(FolderConstants.defaultIcons, id: \.self) { icon in
                    Button(action: { selectedIcon = icon }) {
                        Text(icon)
                            .font(.system(size: 24))
                            .frame(width: 44, height: 44)
                            .background(
                                selectedIcon == icon ? AppColors.primaryBlue.opacity(0.2) : AppColors.surfaceLight
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        selectedIcon == icon ? AppColors.primaryBlue : AppColors.borderLight,
                                        lineWidth: selectedIcon == icon ? 2 : 1
                                    )
                            )
                    }
                    .childSafeTouchTarget()
                }
            }
        }
    }
    
    // MARK: - Color Selection
    private var colorSelectionSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Color")
                .font(AppTypography.titleMedium)
                .foregroundColor(AppColors.textPrimary)
            
            LazyVGrid(columns: GridLayouts.colorGrid, spacing: AppSpacing.sm) {
                ForEach(FolderConstants.defaultColors, id: \.self) { color in
                    Button(action: { selectedColor = color }) {
                        Circle()
                            .fill(Color(hex: color))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .stroke(
                                        selectedColor == color ? AppColors.textPrimary : Color.clear,
                                        lineWidth: 3
                                    )
                            )
                            .overlay(
                                Circle()
                                    .stroke(AppColors.borderLight, lineWidth: 1)
                            )
                            .scaleEffect(selectedColor == color ? 1.1 : 1.0)
                    }
                    .childSafeTouchTarget()
                    .animation(.easeInOut(duration: 0.2), value: selectedColor)
                }
            }
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtonsSection: some View {
        VStack(spacing: AppSpacing.md) {
            // Update Button
            Button(action: { Task { await updateFolder() } }) {
                HStack(spacing: AppSpacing.sm) {
                    if isUpdating {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    
                    Text(isUpdating ? "Updating..." : "Update Folder")
                        .font(AppTypography.titleMedium)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(
                    hasChanges && isValidInput && !isUpdating ? AppColors.primaryBlue : AppColors.buttonDisabled
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!hasChanges || !isValidInput || isUpdating)
            .childSafeTouchTarget()
            
            // Delete Button
            Button(action: { showingDeleteConfirmation = true }) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("Delete Folder")
                        .font(AppTypography.titleMedium)
                        .fontWeight(.semibold)
                }
                .foregroundColor(AppColors.errorRed)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.errorRed.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppColors.errorRed.opacity(0.3), lineWidth: 1)
                )
            }
            .disabled(isUpdating)
            .childSafeTouchTarget()
        }
    }
    
    // MARK: - Actions
    private func updateFolder() async {
        guard hasChanges && isValidInput else { return }
        
        isUpdating = true
        defer { isUpdating = false }
        
        do {
            let trimmedName = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedDescription = folderDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            
            _ = try await folderService.updateFolder(
                folder,
                name: trimmedName != folder.name ? trimmedName : nil,
                description: trimmedDescription != (folder.description ?? "") ? (trimmedDescription.isEmpty ? nil : trimmedDescription) : nil,
                color: selectedColor != folder.color ? selectedColor : nil,
                icon: selectedIcon != folder.icon ? selectedIcon : nil
            )
            
            await MainActor.run {
                dismiss()
            }
            
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func deleteFolder() async {
        isUpdating = true
        defer { isUpdating = false }
        
        do {
            try await folderService.deleteFolder(folder)
            
            await MainActor.run {
                dismiss()
            }
            
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    EditFolderView(
        folder: UserFolder(
            id: "1",
            name: "Family Photos",
            description: "Our favorite family moments and memories",
            color: "#8B5CF6",
            icon: "📁",
            imageCount: 24,
            sortOrder: 0,
            createdAt: "2024-01-15T10:30:00Z",
            updatedAt: "2024-01-15T10:30:00Z",
            createdBy: CreatedBy(
                profileId: "profile_123",
                profileName: "Mom"
            )
        )
    )
}