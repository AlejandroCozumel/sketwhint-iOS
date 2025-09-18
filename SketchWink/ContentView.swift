//
//  ContentView.swift
//  SketchWink
//
//  Created by alejandro on 18/09/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.sectionSpacing) {
                    
                    // App Header
                    VStack(spacing: AppSpacing.elementSpacing) {
                        Text("SketchWink")
                            .appTitle()
                        
                        Text("AI-Powered Creative Platform for Families")
                            .onboardingBody()
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .contentPadding()
                    
                    // Category Cards
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("Content Categories")
                            .headlineLarge()
                            .foregroundColor(AppColors.textPrimary)
                        
                        LazyVGrid(columns: GridLayouts.categoryGrid, spacing: AppSpacing.grid.rowSpacing) {
                            CategoryTestCard(
                                title: "Coloring Pages",
                                icon: "🎨",
                                color: AppColors.coloringPagesColor
                            )
                            
                            CategoryTestCard(
                                title: "Stickers",
                                icon: "✨",
                                color: AppColors.stickersColor
                            )
                            
                            CategoryTestCard(
                                title: "Wallpapers",
                                icon: "🖼️",
                                color: AppColors.wallpapersColor
                            )
                            
                            CategoryTestCard(
                                title: "Mandalas",
                                icon: "🌸",
                                color: AppColors.mandalasColor
                            )
                        }
                    }
                    .cardStyle()
                    
                    // Color Palette Test
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("Color Palette")
                            .headlineLarge()
                            .foregroundColor(AppColors.textPrimary)
                        
                        VStack(spacing: AppSpacing.sm) {
                            HStack(spacing: AppSpacing.xs) {
                                Text("Primary:")
                                    .titleMedium()
                                
                                ColorCircle(color: AppColors.primaryBlue)
                                ColorCircle(color: AppColors.primaryPurple)
                                ColorCircle(color: AppColors.primaryPink)
                                
                                Spacer()
                            }
                            
                            HStack(spacing: AppSpacing.xs) {
                                Text("Accents:")
                                    .titleMedium()
                                
                                ColorCircle(color: AppColors.buttercup)
                                ColorCircle(color: AppColors.limeGreen)
                                ColorCircle(color: AppColors.skyBlue)
                                ColorCircle(color: AppColors.coral)
                                
                                Spacer()
                            }
                        }
                    }
                    .cardStyle()
                    
                    // Button Tests
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("Button Styles")
                            .headlineLarge()
                            .foregroundColor(AppColors.textPrimary)
                        
                        VStack(spacing: AppSpacing.sm) {
                            Button("Generate Art") {}
                                .largeButtonStyle()
                                .childSafeTouchTarget()
                            
                            Button("View Gallery") {}
                                .buttonStyle(
                                    backgroundColor: AppColors.buttonSecondary,
                                    foregroundColor: AppColors.primaryBlue
                                )
                            
                            Button("Settings") {}
                                .buttonStyle(
                                    backgroundColor: AppColors.primaryPurple,
                                    foregroundColor: .white
                                )
                        }
                    }
                    .cardStyle()
                    
                    // Typography Test
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("Typography Scale")
                            .headlineLarge()
                            .foregroundColor(AppColors.textPrimary)
                        
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("Display Large")
                                .displayLarge()
                                .foregroundColor(AppColors.primaryBlue)
                            
                            Text("Headline Medium")
                                .headlineMedium()
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text("Body text for reading content and descriptions. This shows how readable our typography is for children.")
                                .bodyMedium()
                                .foregroundColor(AppColors.textSecondary)
                                .lineSpacing(AppSpacing.lineSpacing)
                            
                            Text("Caption text for metadata")
                                .captionLarge()
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    .cardStyle()
                    
                    // Original SwiftData items (for testing data)
                    if !items.isEmpty {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Text("Test Data Items")
                                .headlineLarge()
                                .foregroundColor(AppColors.textPrimary)
                            
                            ForEach(items) { item in
                                HStack {
                                    Circle()
                                        .fill(AppColors.infoBlue)
                                        .frame(width: 8, height: 8)
                                    
                                    Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                                        .bodySmall()
                                        .foregroundColor(AppColors.textSecondary)
                                    
                                    Spacer()
                                }
                                .contentPadding()
                                .background(AppColors.backgroundLight)
                                .cornerRadius(AppSizing.cornerRadius.sm)
                            }
                        }
                        .cardStyle()
                    }
                    
                    // Add Item Button
                    Button(action: addItem) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                            Text("Add Test Item")
                                .buttonText()
                        }
                    }
                    .largeButtonStyle(backgroundColor: AppColors.successGreen)
                    .childSafeTouchTarget()
                }
                .pageMargins()
                .padding(.vertical, AppSpacing.sectionSpacing)
            }
            .background(AppColors.backgroundLight)
            .navigationTitle("SketchWink")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
