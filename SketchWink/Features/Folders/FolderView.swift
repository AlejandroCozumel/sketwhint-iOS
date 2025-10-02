import SwiftUI

struct FolderView: View {
    @Binding var selectedTab: Int
    @StateObject private var folderService = FolderService.shared
    @StateObject private var profileService = ProfileService.shared
    @State private var searchText = ""
    @State private var showingCreateFolder = false
    @State private var showingFolderImages: UserFolder?
    @State private var selectedFolder: UserFolder?
    @State private var showingEditFolder = false
    @State private var isLoading = true
    @State private var errorMessage: String?

    // Profile filtering (only for admin profiles)
    @State private var selectedProfileFilter: String?
    @State private var showingProfileFilter = false
    
    private var isMainProfile: Bool {
        profileService.currentProfile?.isDefault == true
    }
    
    private var filteredFolders: [UserFolder] {
        var folders = folderService.folders
        
        // Apply search filter
        if !searchText.isEmpty {
            folders = folders.filter { folder in
                folder.name.localizedCaseInsensitiveContains(searchText) ||
                (folder.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // Apply profile filter (only for main profiles)
        if isMainProfile, let profileFilter = selectedProfileFilter {
            folders = folders.filter { folder in
                folder.createdBy.profileId == profileFilter
            }
        }
        
        return folders.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with search and filters - always show at top
            headerSection
            
            // Content
            if isLoading {
                loadingView
            } else if folderService.folders.isEmpty {
                emptyStateView
            } else if filteredFolders.isEmpty {
                noResultsView
            } else {
                folderGridView
            }
            
            Spacer()
        }
        .background(AppColors.backgroundLight)
        .navigationTitle("Folders")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                createFolderButton
            }
        }
        .sheet(isPresented: $showingCreateFolder) {
            CreateFolderView()
        }
        .sheet(item: $showingFolderImages) { folder in
            FolderImagesView(folder: folder, selectedTab: $selectedTab)
        }
        .sheet(item: $selectedFolder) { folder in
            EditFolderView(folder: folder)
        }
        .task {
            await loadFolders()
        }
        .refreshable {
            await loadFolders()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: AppSpacing.sm) {
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
            
            // Profile filter (only for admin profiles)
            if isMainProfile && profileService.availableProfiles.count > 1 {
                profileFilterChips
            }
            
            // Folder count
            if !filteredFolders.isEmpty {
                HStack {
                    Text("\(filteredFolders.count) folder\(filteredFolders.count == 1 ? "" : "s")")
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
    }
    
    // MARK: - Profile Filter Chips
    private var profileFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                // All Profiles chip
                ProfileFilterChip(
                    title: "All Profiles",
                    icon: "👥",
                    isSelected: selectedProfileFilter == nil,
                    action: { selectedProfileFilter = nil }
                )
                
                // Individual profile chips
                ForEach(profileService.availableProfiles, id: \.id) { profile in
                    ProfileFilterChip(
                        title: profile.name,
                        icon: profile.displayAvatar,
                        isSelected: selectedProfileFilter == profile.id,
                        action: { selectedProfileFilter = profile.id }
                    )
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }
    
    // MARK: - Create Folder Button
    private var createFolderButton: some View {
        Button(action: { showingCreateFolder = true }) {
            Image(systemName: "plus")
                .font(AppTypography.titleMedium)
                .foregroundColor(AppColors.primaryBlue)
        }
        .childSafeTouchTarget()
    }
    
    // MARK: - Folder Grid View
    private var folderGridView: some View {
        ScrollView {
            LazyVGrid(columns: GridLayouts.folderGrid, spacing: AppSpacing.grid.itemSpacing) {
                ForEach(filteredFolders, id: \.id) { folder in
                    FolderCard(
                        folder: folder,
                        showCreatorName: isMainProfile && profileService.availableProfiles.count > 1,
                        onTap: { showingFolderImages = folder },
                        onEdit: { selectedFolder = folder }
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
                .font(.system(size: 60))
                .foregroundColor(AppColors.primaryBlue.opacity(0.6))
            
            VStack(spacing: AppSpacing.sm) {
                Text("No Folders Yet")
                    .font(AppTypography.headlineMedium)
                    .foregroundColor(AppColors.textPrimary)
                
                Text("Create your first folder to organize your artwork")
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
                .font(.system(size: 50))
                .foregroundColor(AppColors.textSecondary.opacity(0.6))
            
            VStack(spacing: AppSpacing.sm) {
                Text("No Folders Found")
                    .font(AppTypography.headlineMedium)
                    .foregroundColor(AppColors.textPrimary)
                
                Text("Try adjusting your search or filters")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Button(action: {
                searchText = ""
                selectedProfileFilter = nil
            }) {
                Text("Clear Filters")
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


#Preview {
    FolderView(selectedTab: .constant(3))
        .environmentObject(ProfileService.shared)
}