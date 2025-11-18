import SwiftUI

struct BookCard: View {
    let book: StoryBook
    let showCreatorName: Bool
    let onTap: () -> Void
    let onFavorite: () -> Void
    let onMoveToFolder: () -> Void
    
    @State private var isPressed = false
    @State private var showingActionSheet = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Book Cover Section
                bookCoverSection
                
                // Book Info Section
                bookInfoSection
            }
            .background(AppColors.surfaceLight)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.borderLight, lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .shadow(
                color: AppColors.primaryPink.opacity(0.1),
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
        .contextMenu {
            contextMenuButtons
        }
        .childSafeTouchTarget()
    }
    
    // MARK: - Book Cover Section
    private var bookCoverSection: some View {
        OptimizedAsyncImage(
            url: URL(string: book.coverImageUrl),
            thumbnailSize: 320,
            quality: 0.8,
            content: { optimizedImage in
                ZStack {
                    optimizedImage
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 120)
                        .clipped()
                    
                    // Overlay elements
                    overlayElements
                }
            },
            placeholder: {
                loadingPlaceholder
            }
        )
        .frame(height: 120)
        .clipped()
    }
    
    private var overlayElements: some View {
        ZStack {
            // Top-right: Favorite button
            VStack {
                HStack {
                    Spacer()
                    
                    favoriteButton
                        .padding(.top, AppSpacing.sm)
                        .padding(.trailing, AppSpacing.sm)
                }
                
                Spacer()
            }
            
            // Bottom-left: Creator badge (if needed)
            if showCreatorName,
               let createdBy = book.createdBy,
               !book.isCreatedByCurrentProfile {
                VStack {
                    Spacer()
                    
                    HStack {
                        creatorBadge(createdBy.profileName)
                        Spacer()
                    }
                    .padding(.leading, AppSpacing.sm)
                    .padding(.bottom, AppSpacing.sm)
                }
            }
            
            // Bottom-right: Pages indicator
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    pagesIndicator
                        .padding(.trailing, AppSpacing.sm)
                        .padding(.bottom, AppSpacing.sm)
                }
            }
            
            // Center: Folder indicator (if in folder)
            if book.inFolder {
                folderIndicator
            }
        }
    }
    
    private var favoriteButton: some View {
        AnimatedFavoriteButton(
            isFavorite: book.isFavorite,
            onToggle: onFavorite
        )
    }
    
    private var pagesIndicator: some View {
        Text("\(book.totalPages) pages")
            .font(AppTypography.captionSmall)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
    }
    
    private var folderIndicator: some View {
        Image(systemName: "folder.fill")
            .font(.system(size: 24))
            .foregroundColor(AppColors.primaryPink)
            .background(.ultraThinMaterial, in: Circle())
            .frame(width: 40, height: 40)
            .shadow(color: AppColors.primaryPink.opacity(0.3), radius: 4, x: 0, y: 2)
    }
    
    private var loadingPlaceholder: some View {
        Rectangle()
            .fill(AppColors.borderLight)
            .frame(height: 120)
            .overlay(
                ProgressView()
                    .tint(AppColors.primaryPink)
            )
    }
    
    private var errorPlaceholder: some View {
        Rectangle()
            .fill(AppColors.borderLight)
            .frame(height: 120)
            .overlay(
                VStack(spacing: AppSpacing.xs) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 24))
                        .foregroundColor(AppColors.textSecondary)
                    
                    Text("📚")
                        .font(.system(size: 20))
                }
            )
    }
    
    // MARK: - Book Info Section  
    private var bookInfoSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            // Book title (up to 2 lines)
            Text(book.title)
                .font(AppTypography.titleMedium)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Category (single line)
            Text(book.category)
                .font(AppTypography.captionLarge)
                .foregroundColor(AppColors.primaryPink)
                .fontWeight(.medium)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Date (single line below category)
            Text(book.formattedCreatedAt)
                .font(.system(size: 10))
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.sm)
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
    
    // MARK: - Context Menu
    private var contextMenuButtons: some View {
        Group {
            Button {
                onFavorite()
            } label: {
                Label(
                    book.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: book.isFavorite ? "heart.slash" : "heart"
                )
            }
            
            Button {
                onMoveToFolder()
            } label: {
                Label("Move to Folder", systemImage: "folder")
            }
        }
    }
}

#Preview {
    VStack(spacing: AppSpacing.md) {
        BookCard(
            book: StoryBook(
                id: "1",
                title: "The Sleepy Kitten's Adventure",
                description: "A wonderful bedtime story about a curious kitten",
                coverImageUrl: "https://example.com/cover.jpg",
                totalPages: 8,
                category: "Bedtime Stories",
                isFavorite: false,
                inFolder: false,
                createdAt: "2025-01-23T10:30:00.000Z",
                updatedAt: "2025-01-23T10:30:00.000Z",
                createdBy: CreatedByProfile(
                    profileId: "profile_123",
                    profileName: "Dad",
                    profileAvatar: "👨"
                )
            ),
            showCreatorName: true,
            onTap: { print("Book tapped") },
            onFavorite: { print("Favorite toggled") },
            onMoveToFolder: { print("Move to folder") }
        )
        
        BookCard(
            book: StoryBook(
                id: "2",
                title: "Space Adventure with Ruby",
                description: nil,
                coverImageUrl: "https://example.com/cover2.jpg",
                totalPages: 12,
                category: "Adventure Stories",
                isFavorite: true,
                inFolder: true,
                createdAt: "2025-01-23T09:15:00.000Z",
                updatedAt: "2025-01-23T09:15:00.000Z",
                createdBy: CreatedByProfile(
                    profileId: "profile_456",
                    profileName: "Emma",
                    profileAvatar: "👧"
                )
            ),
            showCreatorName: false,
            onTap: { print("Book tapped") },
            onFavorite: { print("Favorite toggled") },
            onMoveToFolder: { print("Move to folder") }
        )
    }
    .padding()
    .background(AppColors.backgroundLight)
}