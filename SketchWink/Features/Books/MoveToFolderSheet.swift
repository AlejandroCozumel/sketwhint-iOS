import SwiftUI

struct MoveToFolderSheet: View {
    let book: StoryBook
    let folders: [UserFolder]
    let onMove: (String, String?) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFolder: UserFolder?
    @State private var notes: String = ""
    @State private var isMoving = false
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Book info
                bookInfoSection
                
                // Folder selection
                folderSelectionSection
                
                // Notes section
                notesSection
                
                Spacer()
                
                // Action buttons
                actionButtons
            }
            .padding(AppSpacing.md)
            .navigationTitle("Move to Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primaryBlue)
                }
            }
        }
        .presentationDetents([.large])
    }
    
    // MARK: - Book Info Section
    private var bookInfoSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Moving Book")
                .font(AppTypography.titleMedium)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
            
            HStack(spacing: AppSpacing.md) {
                AsyncImage(url: URL(string: book.coverImageUrl)) { imagePhase in
                    switch imagePhase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    case .failure(_), .empty:
                        Rectangle()
                            .fill(AppColors.borderLight)
                            .frame(width: 60, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                Image(systemName: "book.closed")
                                    .foregroundColor(AppColors.textSecondary)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(book.title)
                        .font(AppTypography.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                    
                    Text("\(book.totalPages) pages • \(book.category)")
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.surfaceLight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Folder Selection Section
    private var folderSelectionSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Select Folder")
                .font(AppTypography.titleMedium)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
            
            if folders.isEmpty {
                emptyFoldersView
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.sm) {
                        ForEach(folders) { folder in
                            FolderSelectionRow(
                                folder: folder,
                                isSelected: selectedFolder?.id == folder.id,
                                onSelect: {
                                    selectedFolder = folder
                                }
                            )
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
    }
    
    private var emptyFoldersView: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 32))
                .foregroundColor(AppColors.textSecondary)
            
            Text("No folders available")
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
            
            Text("Create a folder first from the Folders tab")
                .font(AppTypography.captionLarge)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(AppColors.surfaceLight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Notes Section
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Notes (optional)")
                .font(AppTypography.bodyMedium)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textPrimary)
            
            TextField("Add notes about this book...", text: $notes, axis: .vertical)
                .font(AppTypography.bodyMedium)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(3...6)
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: AppSpacing.md) {
            Button {
                moveBook()
            } label: {
                HStack {
                    if isMoving {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "folder.badge.plus")
                    }
                    
                    Text(isMoving ? "Moving..." : "Move to Folder")
                        .font(AppTypography.titleMedium)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .largeButtonStyle(backgroundColor: selectedFolder != nil ? AppColors.primaryBlue : AppColors.buttonDisabled)
            .disabled(selectedFolder == nil || isMoving)
            .childSafeTouchTarget()
        }
    }
    
    // MARK: - Actions
    private func moveBook() {
        guard let folder = selectedFolder else { return }
        
        isMoving = true
        
        let notesToSend = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        onMove(folder.id, notesToSend.isEmpty ? nil : notesToSend)
        
        // Don't dismiss here - let the parent handle dismissal after completion
        // dismiss()
    }
}

// MARK: - Folder Selection Row

struct FolderSelectionRow: View {
    let folder: UserFolder
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: AppSpacing.md) {
                // Folder icon
                ZStack {
                    Circle()
                        .fill(Color(hex: folder.color).opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Text(folder.icon)
                        .font(.system(size: 20))
                }
                
                // Folder info
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(folder.name)
                        .font(AppTypography.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textPrimary)
                    
                    HStack {
                        Text("\(folder.imageCount) items")
                            .font(AppTypography.captionLarge)
                            .foregroundColor(AppColors.textSecondary)
                        
                        if let creatorName = folder.createdBy.profileName {
                            Text("• by \(creatorName)")
                                .font(AppTypography.captionLarge)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
                
                Spacer()
                
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? AppColors.primaryBlue : AppColors.textSecondary)
            }
            .padding(AppSpacing.md)
            .background(isSelected ? AppColors.primaryBlue.opacity(0.1) : AppColors.surfaceLight)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppColors.primaryBlue : AppColors.borderLight, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .childSafeTouchTarget()
    }
}

#Preview {
    MoveToFolderSheet(
        book: StoryBook(
            id: "preview_book",
            title: "The Sleepy Kitten's Adventure",
            description: "A wonderful bedtime story",
            coverImageUrl: "https://example.com/cover.jpg",
            totalPages: 4,
            category: "Bedtime Stories",
            isFavorite: false,
            inFolder: false,
            createdAt: "2025-01-23T10:30:00.000Z",
            updatedAt: "2025-01-23T10:30:00.000Z",
            createdBy: nil
        ),
        folders: [
            UserFolder(
                id: "1",
                name: "Family Stories",
                description: "Our favorite family stories",
                color: "#8B5CF6",
                icon: "📚",
                imageCount: 12,
                sortOrder: 0,
                createdAt: "2025-01-23T10:30:00Z",
                updatedAt: "2025-01-23T10:30:00Z",
                createdBy: CreatedBy(profileId: "profile_123", profileName: "Dad")
            ),
            UserFolder(
                id: "2",
                name: "Adventure Books",
                description: "Exciting adventure stories",
                color: "#10B981",
                icon: "🌟",
                imageCount: 8,
                sortOrder: 1,
                createdAt: "2025-01-23T10:30:00Z",
                updatedAt: "2025-01-23T10:30:00Z",
                createdBy: CreatedBy(profileId: "profile_456", profileName: "Mom")
            )
        ],
        onMove: { folderId, notes in
            print("Moving book to folder \(folderId) with notes: \(notes ?? "none")")
        }
    )
}