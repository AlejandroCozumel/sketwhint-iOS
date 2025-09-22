import SwiftUI

struct ProfilesView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.sectionSpacing) {
                    
                    // Header
                    VStack(spacing: AppSpacing.lg) {
                        ZStack {
                            Circle()
                                .fill(AppColors.primaryPink)
                                .frame(width: 120, height: 120)
                                .shadow(
                                    color: AppColors.primaryPink.opacity(0.3),
                                    radius: AppSizing.shadows.large.radius,
                                    x: AppSizing.shadows.large.x,
                                    y: AppSizing.shadows.large.y
                                )
                            
                            Text("👨‍👩‍👧‍👦")
                                .font(.system(size: 60))
                        }
                        
                        VStack(spacing: AppSpacing.sm) {
                            Text("Family Profiles")
                                .displayMedium()
                                .foregroundColor(AppColors.textPrimary)
                                .multilineTextAlignment(.center)
                            
                            Text("Manage family member profiles and parental controls")
                                .bodyMedium()
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .contentPadding()
                    
                    // Coming Soon Card
                    VStack(spacing: AppSpacing.md) {
                        Text("Coming Soon!")
                            .headlineLarge()
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text("Family profiles with parental controls, usage tracking, and personalized experiences for each family member.")
                            .bodyMedium()
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                        
                        // Feature List
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            FeatureListItem(icon: "👶", title: "Child Profiles", description: "Safe, age-appropriate content")
                            FeatureListItem(icon: "🔒", title: "Parental Controls", description: "Time limits and content filtering")
                            FeatureListItem(icon: "📊", title: "Usage Analytics", description: "Track creative progress")
                            FeatureListItem(icon: "🎨", title: "Personal Collections", description: "Individual art galleries")
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.surfaceLight)
                        .cornerRadius(AppSizing.cornerRadius.md)
                    }
                    .cardStyle()
                }
                .pageMargins()
                .padding(.vertical, AppSpacing.sectionSpacing)
            }
            .background(AppColors.backgroundLight)
            .navigationTitle("Profiles")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct FeatureListItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Text(icon)
                .font(.system(size: AppSizing.iconSizes.lg))
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .titleMedium()
                    .foregroundColor(AppColors.textPrimary)
                
                Text(description)
                    .captionLarge()
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
        }
    }
}

#if DEBUG
struct ProfilesView_Previews: PreviewProvider {
    static var previews: some View {
        ProfilesView()
    }
}
#endif