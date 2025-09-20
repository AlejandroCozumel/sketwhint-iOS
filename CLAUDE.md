# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview: SketchWink iOS App

**SketchWink** is a family-friendly AI-powered creative platform that generates coloring pages, stickers, wallpapers, and mandalas specifically designed for children and families. This iOS app connects to a comprehensive backend API to provide safe, educational, and entertaining AI-generated content.

### Target Audience
- **Primary**: Children ages 4-12 with parental supervision
- **Secondary**: Families seeking safe, creative digital activities
- **Tertiary**: Educators and childcare providers

### Core Value Proposition
- 🤖 **Safe AI Content**: Family-friendly AI-generated art using Seedream-4 and FLUX models
- 👨‍👩‍👧‍👦 **Family Profiles**: Netflix-style profile management with PIN protection and parental controls
- 🎨 **Educational Focus**: Coloring pages, biblical themes, nature content, and learning-oriented designs
- 📱 **Child-Friendly UX**: Simple, intuitive interface designed for young users
- 🔒 **Parental Control**: Complete oversight of content access, purchases, and usage

## iOS Development Requirements

**Target iOS Version**: iOS 18+ (latest iOS features and APIs)
**Swift Version**: Swift 6.0+ 
**Xcode Version**: Xcode 16+

## 🚨 **CRITICAL: Design System Usage - MANDATORY**

### **Typography Usage - ALWAYS Use AppTypography**
```swift
// ✅ CORRECT - Use font() with AppTypography constants
Text("Hello World")
    .font(AppTypography.bodyLarge)
    .foregroundColor(AppColors.textPrimary)

// ✅ CORRECT - Typography extensions work ONLY on Text objects
Text("Hello World")
    .bodyLarge()  // This works because it's a Text object

// ❌ WRONG - Extensions don't work on other views
Button("Click Me") {}
    .bodyLarge()  // ERROR: Extensions only work on Text

// ✅ CORRECT - Use font() for non-Text views
Button("Click Me") {}
    .font(AppTypography.bodyLarge)

// ✅ CORRECT - TextField and other views
TextField("Enter text", text: $text)
    .font(AppTypography.bodyMedium)  // Use .font(), not .bodyMedium()
```

**Available Typography Constants:**
- `AppTypography.displayLarge` (42pt, heavy, rounded)
- `AppTypography.headlineLarge` (26pt, bold, rounded)
- `AppTypography.headlineMedium` (24pt, semibold, rounded)
- `AppTypography.titleMedium` (18pt, medium)
- `AppTypography.bodyLarge` (18pt, regular)
- `AppTypography.bodyMedium` (16pt, regular)
- `AppTypography.captionLarge` (14pt, regular)
- `AppTypography.buttonLarge` (22pt, bold, rounded)

### **Colors Usage - ALWAYS Use AppColors**
```swift
// ✅ CORRECT - Use AppColors constants
.foregroundColor(AppColors.textPrimary)
.background(AppColors.backgroundLight)
.tint(AppColors.primaryBlue)

// ❌ WRONG - Never use custom colors or hex values
.foregroundColor(Color.blue)
.background(Color(hex: "#FF0000"))
```

**Available Color Constants:**
- **Primary**: `AppColors.primaryBlue`, `AppColors.primaryPurple`, `AppColors.primaryPink`
- **Categories**: `AppColors.coloringPagesColor`, `AppColors.stickersColor`, `AppColors.wallpapersColor`, `AppColors.mandalaColor`
- **Text**: `AppColors.textPrimary`, `AppColors.textSecondary`, `AppColors.textOnDark`
- **Backgrounds**: `AppColors.backgroundLight`, `AppColors.surfaceLight`
- **Interactive**: `AppColors.buttonPrimary`, `AppColors.buttonSecondary`, `AppColors.buttonDisabled`
- **States**: `AppColors.successGreen`, `AppColors.errorRed`, `AppColors.warningOrange`, `AppColors.infoBlue`
- **Borders**: `AppColors.borderLight`, `AppColors.borderMedium`, `AppColors.borderDark`

### **Spacing Usage - ALWAYS Use AppSpacing**
```swift
// ✅ CORRECT - Use AppSpacing constants
.padding(AppSpacing.md)
.spacing(AppSpacing.lg)

// ✅ CORRECT - Use semantic spacing
.contentPadding()  // Extension for standard content padding
.pageMargins()     // Extension for page margins
.cardStyle()       // Extension for card styling

// ❌ WRONG - Never use hardcoded values
.padding(16)
.spacing(24)
```

**Available Spacing Constants:**
- `AppSpacing.xs` (8pt), `AppSpacing.sm` (12pt), `AppSpacing.md` (16pt)
- `AppSpacing.lg` (24pt), `AppSpacing.xl` (32pt), `AppSpacing.xxl` (48pt)
- `AppSpacing.sectionSpacing` (24pt), `AppSpacing.elementSpacing` (16pt)

### **Grid Layouts - Use GridLayouts**
```swift
// ✅ CORRECT - Use predefined grid layouts
LazyVGrid(columns: GridLayouts.categoryGrid, spacing: AppSpacing.grid.itemSpacing)
LazyVGrid(columns: GridLayouts.styleGrid, spacing: AppSpacing.grid.itemSpacing)
LazyVGrid(columns: GridLayouts.threeColumnGrid, spacing: AppSpacing.grid.itemSpacing)

// Available grid layouts:
// - GridLayouts.categoryGrid (2 columns)
// - GridLayouts.styleGrid (2 columns)
// - GridLayouts.threeColumnGrid (3 columns)
// - GridLayouts.fourColumnGrid (4 columns)
```

### **Button Styling - Use Extensions**
```swift
// ✅ CORRECT - Use styling extensions
Button("Primary Action") {}
    .largeButtonStyle(backgroundColor: AppColors.primaryBlue)
    .childSafeTouchTarget()

Button("Secondary Action") {}
    .buttonStyle(
        backgroundColor: AppColors.buttonSecondary,
        foregroundColor: AppColors.primaryBlue
    )
```

### **Child-Safe Touch Targets - MANDATORY**
```swift
// ✅ ALWAYS add child-safe touch targets for interactive elements
Button("Tap Me") {}
    .childSafeTouchTarget()  // Ensures minimum 44pt, recommended 56pt

// ✅ Use for all interactive elements
Toggle("Setting", isOn: $setting)
    .childSafeTouchTarget()
```

## 🔧 **API Integration - Use AppConfig Structure**

### **Correct API Configuration**
```swift
// ✅ CORRECT - Use AppConfig.API structure (baseURL includes /api)
private let baseURL = AppConfig.API.baseURL  // "http://127.0.0.1:3000/api"
let endpoint = "\(baseURL)\(AppConfig.API.Endpoints.categories)"  // "/categories/with-options"
// Final URL: "http://127.0.0.1:3000/api/categories/with-options"

// ❌ WRONG - Don't use old APIConfig or hardcoded URLs
private let baseURL = APIConfig.baseURL  // OLD - doesn't exist
let endpoint = "http://localhost:3000/api/categories"  // Hardcoded
```

### **KeychainManager Usage**
```swift
// ✅ CORRECT - Use retrieveToken() and storeToken()
guard let token = try KeychainManager.shared.retrieveToken() else {
    throw AuthError.noToken
}

try KeychainManager.shared.storeToken(sessionToken)

// ❌ WRONG - Old method names
guard let token = try KeychainManager.shared.retrieve() else {  // OLD
    throw AuthError.noToken
}
```

### **API Endpoints Structure**
```swift
// ✅ CORRECT - Use AppConfig.API.Endpoints
let categoriesURL = "\(baseURL)\(AppConfig.API.Endpoints.categories)"
let generationsURL = "\(baseURL)\(AppConfig.API.Endpoints.generations)"
let tokenBalanceURL = "\(baseURL)\(AppConfig.API.Endpoints.tokenBalance)"

// Available endpoints in AppConfig.API.Endpoints:
// - .signUp, .signIn, .verifyOTP, .resendOTP
// - .categories, .generations, .enhancePrompt
// - .images, .imageDownload, .toggleFavorite, .bulkFavorite
// - .collections, .collectionImages, .bulkAddToCollection
// - .subscriptionPlans, .tokenBalance, .featureAccess
// - .analytics
```

## 🐛 **Common SwiftUI Issues & Solutions**

### **AsyncImage Type Conversion**
```swift
// ✅ CORRECT - AsyncImage returns SwiftUI Image, not UIImage
AsyncImage(url: URL(string: imageUrl)) { imagePhase in
    switch imagePhase {
    case .success(let swiftUIImage):
        swiftUIImage  // Use directly, don't wrap in Image()
            .resizable()
            .aspectRatio(contentMode: .fit)
    case .failure(_):
        // Handle error
    case .empty:
        ProgressView()
    @unknown default:
        EmptyView()
    }
}

// ❌ WRONG - Don't try to convert to UIImage in success case
case .success(let uiImage):
    Image(uiImage: uiImage)  // ERROR: uiImage is actually SwiftUI Image
```

### **Image Conversion for Sharing**
```swift
// ✅ CORRECT - Convert URL to UIImage for sharing
Task {
    if let url = URL(string: imageUrl),
       let data = try? Data(contentsOf: url),
       let uiImage = UIImage(data: data) {
        shareableImage = uiImage
    }
}
```

### **Navigation and Modifiers**
```swift
// ✅ CORRECT - Navigation in iOS 18+
NavigationView {
    // Content
}
// or
NavigationStack {
    // Content
}

// ✅ CORRECT - Environment dismiss
@Environment(\.dismiss) private var dismiss
Button("Close") {
    dismiss()
}
```

## 📱 **Component Naming Conventions**

### **Avoid Naming Conflicts**
```swift
// ✅ CORRECT - Use descriptive, unique names
struct GenerationInfoRow: View { }
struct ProfileInfoCard: View { }
struct CategorySelectionGrid: View { }

// ❌ WRONG - Generic names that might conflict
struct InfoRow: View { }  // Might conflict with existing InfoRow
struct Card: View { }     // Too generic
```

### **File Organization**
```
SketchWink/
├── Constants/
│   ├── Colors.swift       ✅ AppColors
│   ├── Typography.swift   ✅ AppTypography  
│   ├── Spacing.swift      ✅ AppSpacing, GridLayouts
│   └── AppConfig.swift    ✅ AppConfig.API
├── Features/
│   └── Generation/
│       ├── GenerationView.swift
│       ├── GenerationProgressView.swift
│       ├── GenerationResultView.swift
│       └── ColoringView.swift
├── Models/
│   └── GenerationModels.swift
└── Services/
    ├── AuthService.swift
    └── GenerationService.swift
```

### iOS 18+ Features to Leverage
- **SwiftUI 6.0**: Latest UI framework capabilities
- **Swift 6.0**: Modern concurrency and performance improvements
- **SwiftData**: Native data persistence
- **App Intents**: Enhanced Siri integration for voice commands
- **Control Center Widgets**: Quick generation shortcuts
- **Interactive Widgets**: Live activity updates for generation progress
- **Privacy Enhancements**: Advanced permission handling for family safety

### Key iOS-Specific Features to Implement

#### 1. Family Safety & Parental Controls
- **Screen Time Integration**: Respect parental time limits
- **Child Safety API**: Content filtering and reporting
- **Family Sharing**: Subscription sharing across family members
- **Guided Access**: Lock app in specific modes for children

#### 2. Creative Tools Integration
- **Apple Pencil Support**: Natural drawing and coloring experience
- **Haptic Feedback**: Engaging tactile responses for children
- **Photos Integration**: Save creations to family photo library
- **AirDrop Sharing**: Easy sharing between family devices
- **AirPrint**: Direct printing of coloring pages

#### 3. Educational Features
- **VoiceOver**: Full accessibility for children with visual impairments
- **Dynamic Type**: Large text support for early readers
- **Multilingual Support**: Localization for global families

#### 4. Modern iOS Capabilities
- **Background App Refresh**: Continue generation when app backgrounded
- **Focus Modes**: Integrate with "Do Not Disturb" and "School" modes
- **Shortcuts Integration**: Automate common tasks
- **Live Activities**: Show generation progress on lock screen

## Backend Integration

The app connects to a production-ready backend API with the following endpoints:

### Base Configuration
```swift
struct APIConfig {
    static let baseURL = "https://api.sketchwink.com/api"  // Production
    // static let baseURL = "http://localhost:3000/api"  // Development
}
```

### Core API Features
- **Authentication**: Sign-up, sign-in, email verification
- **Family Profiles**: Create, manage, and switch between family member profiles
- **AI Generation**: 4 content categories (coloring pages, stickers, wallpapers, mandalas)
- **Subscription Management**: 9 tiers from free to business plans
- **Content Library**: Collections, favorites, and advanced filtering
- **Analytics**: Usage tracking and parental insights

## App Architecture Requirements

### Design Patterns
- **MVVM with Combine**: Reactive programming for real-time updates
- **Repository Pattern**: Clean API abstraction layer
- **Child-Safe Navigation**: Simple, large buttons and clear visual hierarchy
- **Offline-First**: Cache content for use without internet

### 🎨 Design System Constants - MANDATORY USAGE

#### Colors (AppColors)
```swift
// ALWAYS use AppColors constants, NEVER custom colors or gradients
AppColors.primaryBlue      // #37B6F6 - Picton Blue (primary actions)
AppColors.primaryPurple    // #882FF6 - Blue-Violet (creative/magical)
AppColors.primaryPink      // #FF6B9D - Bubblegum Pink (playful/warm)

// Content Categories
AppColors.coloringPagesColor  // #F97316 - Orange (creative expression)
AppColors.stickersColor      // #10B981 - Emerald (fun/playful)
AppColors.wallpapersColor    // #8B5CF6 - Purple (imagination)
AppColors.mandalaColor       // #EC4899 - Pink (mindfulness)

// UI Semantic Colors
AppColors.backgroundLight    // #FEFEFE - Pure white backgrounds
AppColors.textPrimary       // #1F2937 - Primary text
AppColors.textSecondary     // #6B7280 - Secondary text
AppColors.errorRed          // #EF4444 - Error states
```

#### Typography (AppTypography)
```swift
// Child-optimized typography - minimum 14pt fonts
.displayLarge()    // 42pt, heavy, rounded - App titles
.headlineLarge()   // 28pt, bold, rounded - Section headers
.titleMedium()     // 18pt, semibold - Form labels
.bodyMedium()      // 16pt, regular - Body text
.buttonLarge()     // 18pt, semibold - Primary buttons

// ALWAYS use these extensions, NEVER raw Font.system()
```

#### Spacing & Touch Targets (AppSpacing/AppSizing)
```swift
// Child-safe spacing
AppSpacing.xs      // 4pt
AppSpacing.md      // 16pt
AppSpacing.xl      // 32pt

// Child-safe touch targets
.childSafeTouchTarget()    // Minimum 44pt, recommended 56pt
.largeButtonStyle()        // Consistent button styling
.cardStyle()              // Consistent card styling
```

### Security Requirements
- **Keychain Storage**: Secure token and sensitive data storage
- **Certificate Pinning**: Prevent man-in-the-middle attacks
- **Data Encryption**: Encrypt all local user data
- **COPPA Compliance**: Follow children's privacy regulations

### Performance Requirements
- **Fast Launch**: App should launch in under 2 seconds
- **Smooth Animations**: 60fps animations for engaging UX
- **Memory Efficient**: Optimize for older devices children might use
- **Battery Conscious**: Minimize impact on device battery life

## Content Categories & Features

### 1. Coloring Pages
- **Options**: Cartoon, Japanese, Realistic, Biblical styles
- **Interactive Coloring**: Built-in digital coloring tools
- **Print Support**: High-quality PDF export for physical coloring

### 2. Stickers
- **Categories**: Animals, Food, Emoji, Nature, Adventure
- **Usage**: Digital sticker books and photo decoration
- **Background Removal**: Clean PNG exports

### 3. Wallpapers
- **Themes**: Fantasy, Adventure, Animals, Rainbow, Space, Nature, Characters, Patterns
- **Device Optimization**: Multiple aspect ratios for different devices
- **Live Wallpaper**: Animated wallpapers where possible

### 4. Mandalas
- **Complexity Levels**: Simple to Complex based on child's age
- **Styles**: Geometric, Nature, Animal, Floral patterns
- **Mindfulness**: Promote calm, focused creativity

## Safety & Educational Guidelines

### Content Safety
- All AI-generated content must be appropriate for children ages 4+
- Biblical content follows family-friendly religious guidelines
- No violent, scary, or inappropriate imagery
- Automatic content filtering using AI safety models

### Educational Value
- Promote creativity and artistic expression
- Encourage fine motor skill development through coloring
- Support learning through themed content (animals, nature, etc.)
- Provide positive reinforcement and achievement systems

### Parental Features
- **Usage Reports**: Time spent, content generated, educational progress
- **Content Review**: Parents can preview all generated content
- **Purchase Controls**: Require parental approval for all transactions
- **Time Limits**: Built-in usage time management

## Development Commands

```bash
# Development
open SketchWink.xcodeproj
# Build and run on simulator
cmd+R

# Testing
cmd+U  # Run unit tests
cmd+shift+U  # Run UI tests

# Archive for App Store
Product > Archive
```

## Key Files Structure
```
SketchWink/
├── SketchWink/
│   ├── App/
│   │   ├── SketchWinkApp.swift
│   │   ├── ContentView.swift
│   │   └── AppCoordinator.swift
│   ├── Constants/  ✨ IMPORTANT: Use these constants for ALL UI
│   │   ├── Colors.swift        # Research-based child-friendly colors
│   │   ├── Typography.swift    # Child-optimized fonts and text styles
│   │   ├── Spacing.swift       # Child-safe spacing and touch targets
│   │   └── AppConfig.swift     # API endpoints and app configuration
│   ├── Features/
│   │   ├── Authentication/
│   │   │   ├── LoginView.swift
│   │   │   └── LoginViewModel.swift
│   │   ├── Main/
│   │   │   └── MainAppView.swift
│   │   ├── FamilyProfiles/
│   │   ├── Generation/
│   │   ├── Gallery/
│   │   └── Settings/
│   ├── Services/
│   │   ├── AuthService.swift    # Complete auth with Keychain storage
│   │   └── ContentFilterService.swift
│   ├── Models/
│   └── Utils/
├── SketchWinkTests/
├── SketchWinkUITests/
├── iOS_Development_Guide.md
└── CLAUDE.md
```

## App Store Guidelines Compliance

### Family-Friendly App Requirements
- Age rating: 4+ (Made for Kids category)
- No third-party advertising
- No social features or user-generated content sharing
- Clear privacy policy for children's data
- Parental gate for all purchases

### Subscription Guidelines
- Clear subscription terms and pricing
- Easy cancellation process
- Family Sharing support
- Restore purchases functionality

## Success Metrics

### Child Engagement
- Daily active users (children)
- Time spent creating vs. consuming
- Completion rate of coloring activities
- Return usage patterns

### Family Satisfaction
- Parent approval ratings
- Family account growth
- Subscription retention
- App Store ratings and reviews

### Educational Impact
- Creative output per child
- Skill progression tracking
- Educational content engagement
- Parent-reported learning outcomes

---

## Important Notes for Claude

### 🚨 CRITICAL: Design System Compliance
1. **ALWAYS use AppColors constants** - Never use custom colors, gradients, or hex values directly
2. **ALWAYS use AppTypography extensions** - Never use raw `Font.system()` calls
3. **ALWAYS use AppSpacing constants** - Never use hardcoded spacing values
4. **ALWAYS use AppSizing touch targets** - Ensure child-safe button sizes with `.childSafeTouchTarget()`
5. **ALWAYS use semantic styling** - Use `.cardStyle()`, `.largeButtonStyle()`, `.formFieldStyle()`

### 🎯 Development Guidelines
6. **Always prioritize child safety** in all features and implementations
7. **Follow iOS 18+ best practices** - fetch latest iOS development patterns and APIs
8. **Implement proper parental controls** for all features that involve children
9. **Ensure COPPA compliance** in all data handling and privacy features
10. **Design for accessibility** - support children with different abilities
11. **Focus on educational value** while maintaining fun and engagement
12. **Test on actual devices** children would use, not just latest hardware
13. **Follow Apple's Human Interface Guidelines** specifically for family apps

### 🔍 Pre-Implementation Checklist
Before writing any UI code, ask:
- Am I using AppColors constants instead of custom colors?
- Am I using AppTypography extensions instead of raw fonts?
- Am I using AppSpacing constants for proper spacing?
- Are all touch targets child-safe (44pt minimum, 56pt recommended)?
- Is this safe for a 4-year-old to use independently?
- Does this require parental oversight or approval?
- Is the UI simple enough for young children?
- Does this provide educational or creative value?
- Is this compliant with children's privacy laws?

### 🎨 Design System Examples
```swift
// ✅ CORRECT - Using constants
Text("Welcome")
    .displayLarge()                    // AppTypography
    .foregroundColor(AppColors.primaryBlue)  // AppColors
    .padding(AppSpacing.lg)            // AppSpacing

Button("Sign In") { }
    .largeButtonStyle(backgroundColor: AppColors.primaryBlue)  // Semantic styling
    .childSafeTouchTarget()            // Child-safe touch

// ❌ WRONG - Custom styling
Text("Welcome")
    .font(.system(size: 42, weight: .heavy))
    .foregroundColor(Color.blue)
    .padding(24)
```

This app should be a trusted digital creative companion for families, promoting safe, educational, and joyful creative expression for children while maintaining strict adherence to our research-based design system.

---

## ✅ **GENERATION OPTIONS SYSTEM - FULLY IMPLEMENTED**

**Status:** 100% Complete with Subscription-Based Feature Restrictions  
**Last Updated:** January 19, 2025

### 📱 **Complete Generation Flow Implementation**

The iOS app now includes a comprehensive generation options system that perfectly matches the backend API specification and implements proper subscription-based feature restrictions.

#### **🎯 Implemented Generation Options:**

1. **📸 Max Images Selector** (1-4 images)
   - **Free Users**: Limited to 1 image only
   - **Paid Users**: Can select up to 4 image variations
   - **UI**: Clean button grid with upgrade prompts for restricted options
   - **API Field**: `maxImages: Int`

2. **⚡ Quality Selector** (standard/high/ultra)
   - **Free/Basic/Pro Users**: Limited to "standard" quality only
   - **Max+ Users**: Access to "high" and "ultra" quality options
   - **UI**: Vertical list with descriptions and lock icons for premium options
   - **API Field**: `quality: String`
   - **Descriptions**: 
     - Standard: "Fast generation, good quality"
     - High: "Better quality, slower generation" 
     - Ultra: "Best quality, longest generation time"

3. **🤖 AI Model Selector** (seedream/flux)
   - **Free/Basic/Pro/Max Users**: Limited to "seedream" model only
   - **Business Users**: Access to "flux" model for advanced generation
   - **UI**: Vertical list with model descriptions and upgrade prompts
   - **API Field**: `model: String`
   - **Descriptions**:
     - Seedream: "Fast, family-friendly AI model"
     - Flux: "Advanced model with more detail"

4. **📐 Dimensions Selector** (1:1, 2:3, 3:2, A4)
   - **All Users**: Full access to all dimension options
   - **Smart Defaults**: Automatically set based on content category
   - **UI**: Horizontal button grid with aspect ratio descriptions
   - **API Field**: `dimensions: String`
   - **Smart Defaults**:
     - Coloring Pages & Mandalas: `2:3` (Portrait)
     - Stickers: `1:1` (Square)  
     - Wallpapers: `3:2` (Landscape)
     - Default: `1:1` (Square)

#### **📋 Complete API Request Format**

The iOS app now sends the complete generation request matching the backend specification:

```json
{
  "prompt": "a cute dog playing in the garden",
  "categoryId": "coloring_pages",
  "optionId": "cartoon_style", 
  "maxImages": 1,
  "quality": "standard",
  "model": "seedream",
  "dimensions": "2:3",
  "familyProfileId": null
}
```

#### **🔒 Subscription-Based Feature Restrictions**

**Feature Access Matrix:**

| Feature | Free | Basic | Pro | Max | Business |
|---------|------|-------|-----|-----|----------|
| **Max Images** | 1 only | 1-4 ✅ | 1-4 ✅ | 1-4 ✅ | 1-4 ✅ |
| **Quality** | standard only | standard only | standard only | standard/high/ultra ✅ | standard/high/ultra ✅ |
| **AI Models** | seedream only | seedream only | seedream only | seedream only | seedream/flux ✅ |
| **Dimensions** | All ✅ | All ✅ | All ✅ | All ✅ | All ✅ |

#### **💡 User Experience Features**

1. **Upgrade Prompts**: When users tap restricted features, they see contextual alerts:
   - "Multiple Images requires Basic or higher subscription"
   - "High/Ultra Quality requires Max or higher subscription" 
   - "Multiple AI Models requires Business subscription"

2. **Visual Indicators**:
   - 🔒 Lock icons on premium features
   - ✅ Checkmark icons on selected options
   - Disabled state styling for restricted options

3. **Child-Friendly Design**:
   - Large touch targets (56pt recommended)
   - Clear descriptions for each option
   - Consistent AppColors and AppTypography usage
   - Card-based layout with proper spacing

#### **🛠 Technical Implementation**

**State Management:**
```swift
@State private var selectedMaxImages = 1
@State private var selectedQuality = "standard" 
@State private var selectedModel = "seedream"
@State private var selectedDimensions = "1:1"
```

**Request Generation:**
```swift
let request = CreateGenerationRequest(
    categoryId: selectedCategory.category.id,
    optionId: selectedOption.id,
    prompt: userPrompt.trimmingCharacters(in: .whitespacesAndNewlines),
    quality: selectedQuality,
    dimensions: selectedDimensions, 
    maxImages: selectedMaxImages,
    model: selectedModel,
    familyProfileId: nil
)
```

**API Logging:**
All generation requests include comprehensive debug logging:
- 📤 Request body with all selected options
- 📥 Complete API response
- 🔍 Easy debugging of generation parameters

#### **🔄 Future Integration Points**

1. **Family Profiles**: `familyProfileId` field ready for family profile system integration
2. **Dynamic Permissions**: Structure ready for `/user/token-balance` permissions API integration  
3. **Input Images**: Model supports `inputImage` field for future image-to-image generation
4. **Real-time Restrictions**: Easy to connect to live subscription status checking

#### **✅ Quality Assurance**

- **Design System Compliance**: 100% usage of AppColors, AppTypography, and AppSpacing constants
- **Child Safety**: All UI elements meet child-safe touch target requirements
- **Accessibility**: Full VoiceOver support and Dynamic Type compatibility
- **Error Handling**: Comprehensive upgrade prompts and error states
- **Performance**: Efficient state management and minimal re-renders

This implementation provides a complete, production-ready generation options system that seamlessly integrates with the SketchWink subscription model while maintaining the app's family-friendly design principles.

---

## ✅ **SERVER-SENT EVENTS (SSE) SYSTEM - FULLY IMPLEMENTED**

**Status:** 100% Complete with Real-Time Progress Tracking  
**Last Updated:** January 19, 2025

### 📡 **Real-Time Generation Progress Implementation**

The iOS app now includes a comprehensive Server-Sent Events (SSE) system that provides real-time progress updates during AI generation, replacing the previous polling mechanism with efficient real-time communication.

#### **🎯 SSE System Components:**

1. **📡 EventSourceService** - Core iOS SSE Implementation
   - **Native URLSession**: Custom EventSource implementation for iOS
   - **Connection Management**: Automatic reconnection and error handling
   - **Event Parsing**: Proper SSE format parsing (data, event, id fields)
   - **Authentication**: Bearer token support in headers
   - **File**: `EventSourceService.swift`

2. **⚡ GenerationProgressSSEService** - Generation-Specific SSE Handler
   - **Singleton Pattern**: Shared service for app-wide progress tracking
   - **Real-Time Updates**: Live progress percentage and status updates
   - **Status Management**: Complete status lifecycle tracking
   - **Error Handling**: Robust error recovery and user feedback
   - **File**: `GenerationProgressSSEService.swift`

3. **📱 Updated GenerationProgressView** - Real-Time UI
   - **Live Progress Bar**: Real-time percentage updates (0-100%)
   - **Dynamic Status**: Live status messages and icons
   - **Connection State**: Visual connection status indicators
   - **Smooth Animations**: Seamless progress transitions
   - **File**: `GenerationProgressView.swift`

#### **🔄 SSE Workflow:**

```swift
// 1. Connect to User Progress Stream (once per session)
progressSSEService.connectToUserProgress(
    authToken: userToken
)

// 2. Start Generation (existing endpoint)
let generation = try await generationService.createGeneration(request)

// 3. Track Specific Generation
progressSSEService.startTrackingGeneration(generation.id)

// 4. Receive Real-Time Updates (automatic filtering)
progressSSEService.onProgressUpdate = { progress in
    // Update UI with live progress data for tracked generation
    currentProgress = progress  // 0-100% with status
}

// 5. Handle Completion
progressSSEService.onGenerationComplete = { generationId in
    // Fetch final result and show completed generation
    let completed = try await generationService.getGeneration(id: generationId)
    onComplete(completed)
}
```

#### **📊 Generation Status Lifecycle:**

| Status | Progress | Message | Icon | Description |
|--------|----------|---------|------|-------------|
| `queued` | 0% | "Waiting in queue..." | ⏳ | Request accepted, waiting to start |
| `starting` | 10% | "Initializing AI model..." | 🚀 | AI model loading and preparing |
| `processing` | 50% | "Generating your content..." | 🎨 | Active AI generation in progress |
| `completing` | 90% | "Processing images..." | ⚡ | Final image processing and optimization |
| `completed` | 100% | "Ready!" | 🎉 | Generation complete, images available |
| `failed` | 0% | "Generation failed" | ❌ | Error occurred, generation stopped |

#### **🌐 API Endpoints:**

```swift
// SSE Endpoints in AppConfig.API.Endpoints
static let sseGenerationProgress = "/sse/generation-progress/%@" // %@ = generationId (legacy)
static let sseUserProgress = "/sse/user-progress"  // PRIMARY: Track all user generations

// Primary SSE URL (recommended)
// GET /api/sse/user-progress
// Headers: Authorization: Bearer {token}
// Streams all generation progress for the authenticated user
```

#### **📦 SSE Message Format:**

```json
// Connection Established
{
  "type": "connected",
  "message": "Connected to generation progress stream"
}

// Progress Update
{
  "type": "progress",
  "generationId": "gen_123456789",
  "status": "processing",
  "progress": 65,
  "imageCount": 4,
  "error": null
}

// Keep-Alive Ping
{
  "type": "ping",
  "timestamp": "2025-01-19T10:30:00Z"
}
```

#### **🔧 Technical Features:**

- **Real-Time Updates**: Instant progress feedback instead of 2-second polling
- **Efficient Bandwidth**: SSE uses less bandwidth than frequent HTTP requests
- **Connection Recovery**: Automatic reconnection on network issues
- **Background Support**: Continues updating when app backgrounded
- **Memory Efficient**: Proper cleanup and connection management
- **Child-Friendly**: Engaging real-time feedback for young users

#### **📱 UI Enhancements:**

- **Live Progress Bar**: Smooth 0-100% progress animation
- **Dynamic Status Icons**: Animated icons that change with status
- **Connection Indicators**: Visual feedback for SSE connection state
- **Error Recovery**: Clear error messages with retry options
- **Completion Animation**: Celebration animation when generation completes

#### **🎯 Benefits Over Polling:**

1. **Instant Updates**: No 2-second delays between status checks
2. **Reduced Battery**: Less frequent network requests
3. **Better UX**: Real-time feedback keeps children engaged
4. **Server Efficiency**: Reduces server load from constant polling
5. **Scalability**: SSE handles many concurrent users efficiently

This SSE implementation transforms the generation experience from a static waiting screen to an engaging, real-time progress tracker that keeps users (especially children) engaged throughout the AI generation process.

---

## 🔍 **Quick Reference Checklist**

### **Before Writing Any UI Code:**
- [ ] Am I using `AppColors` constants instead of custom colors?
- [ ] Am I using `AppTypography` with `.font()` for non-Text views?
- [ ] Am I using `AppSpacing` constants for all spacing?
- [ ] Are all touch targets child-safe with `.childSafeTouchTarget()`?
- [ ] Am I using semantic styling (`.cardStyle()`, `.largeButtonStyle()`)?

### **Typography Quick Check:**
- [ ] Text views: Use `.bodyLarge()` extensions ✅
- [ ] Other views: Use `.font(AppTypography.bodyLarge)` ✅
- [ ] TextField: Use `.font(AppTypography.bodyMedium)` ✅
- [ ] Button: Use `.font(AppTypography.titleMedium)` ✅

### **API Integration Quick Check:**
- [ ] Using `AppConfig.API.baseURL` not `APIConfig.baseURL`
- [ ] Using `KeychainManager.shared.retrieveToken()` not `.retrieve()`
- [ ] Using `AppConfig.API.Endpoints.categories` for endpoints
- [ ] Proper error handling with custom error types

### **SwiftUI Quick Check:**
- [ ] AsyncImage success case uses `swiftUIImage` not `uiImage`
- [ ] No naming conflicts (use descriptive component names)
- [ ] Proper navigation with NavigationView or NavigationStack
- [ ] Environment dismiss with `@Environment(\.dismiss)`

### **Child Safety Quick Check:**
- [ ] All interactive elements have `.childSafeTouchTarget()`
- [ ] Text size minimum 14pt (use AppTypography constants)
- [ ] Clear visual hierarchy with proper spacing
- [ ] Family-friendly color palette (AppColors only)

**🚨 REMEMBER: Always use the existing constants - never create custom colors, spacing, or typography!**