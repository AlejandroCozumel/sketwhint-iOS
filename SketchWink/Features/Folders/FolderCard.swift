import SwiftUI

struct FolderCard: View {
    let folder: UserFolder
    let showCreatorName: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        ZStack {
            // Main card button
            Button(action: onTap) {
                VStack(spacing: 0) {
                    // Folder Icon Section (without edit button)
                    folderIconSectionWithoutEdit
                    
                    // Folder Info Section
                    folderInfoSection
                }
                .background(AppColors.surfaceLight)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
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
            
            // Floating edit button outside the card
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: onEdit) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(AppColors.primaryBlue, in: Circle())
                            .overlay(
                                Circle()
                                    .stroke(.white, lineWidth: 2)
                            )
                            .shadow(
                                color: AppColors.primaryBlue.opacity(0.4),
                                radius: 4,
                                x: 0,
                                y: 2
                            )
                    }
                    .childSafeTouchTarget()
                    .offset(x: 8, y: -8) // Float outside top-right corner
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Folder Icon Section (without edit button)
    private var folderIconSectionWithoutEdit: some View {
        ZStack {
            // Background color
            Color(hex: folder.color)
                .opacity(0.15)
            
            // Main folder icon
            Text(folder.icon)
                .font(.system(size: 32))
            
            // Creator badge (bottom-left, only if different creator)
            if showCreatorName,
               let creatorName = folder.createdBy.profileName,
               !creatorName.isEmpty {
                VStack {
                    Spacer()
                    
                    HStack {
                        creatorBadge(creatorName)
                        Spacer()
                    }
                    .padding(.leading, AppSpacing.sm)
                    .padding(.bottom, AppSpacing.sm)
                }
            }
        }
        .frame(height: 100)
        .clipped()
    }
    
    // MARK: - Folder Info Section
    private var folderInfoSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            // Folder name
            HStack {
                Text(folder.name)
                    .font(AppTypography.titleMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer()
            }
            
            // Image count
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                
                Text("\(folder.imageCount) image\(folder.imageCount == 1 ? "" : "s")")
                    .font(AppTypography.captionLarge)
                    .foregroundColor(AppColors.textSecondary)
                
                Spacer()
            }
            
            // Description (if available)
            if let description = folder.description, !description.isEmpty {
                Text(description)
                    .font(AppTypography.captionLarge)
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
    }
    
    // MARK: - Creator Badge
    private func creatorBadge(_ creatorName: String) -> some View {
        Text(creatorName)
            .font(AppTypography.captionSmall)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                LinearGradient(
                    colors: [AppColors.primaryPurple, AppColors.primaryBlue],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule()
            )
            .shadow(
                color: AppColors.primaryPurple.opacity(0.3),
                radius: 2,
                x: 0,
                y: 1
            )
    }
}


#Preview {
    VStack(spacing: AppSpacing.md) {
        FolderCard(
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
            ),
            showCreatorName: true,
            onTap: { print("Folder tapped") },
            onEdit: { print("Edit folder") }
        )
        
        FolderCard(
            folder: UserFolder(
                id: "2",
                name: "Kids Art",
                description: nil,
                color: "#10B981",
                icon: "🎨",
                imageCount: 7,
                sortOrder: 1,
                createdAt: "2024-01-15T10:30:00Z",
                updatedAt: "2024-01-15T10:30:00Z",
                createdBy: CreatedBy(
                    profileId: "profile_456",
                    profileName: "Emma"
                )
            ),
            showCreatorName: false,
            onTap: { print("Folder tapped") },
            onEdit: { print("Edit folder") }
        )
    }
    .padding()
    .background(AppColors.backgroundLight)
}