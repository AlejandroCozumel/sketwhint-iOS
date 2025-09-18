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
│   │   └── ContentView.swift
│   ├── Features/
│   │   ├── Authentication/
│   │   ├── FamilyProfiles/
│   │   ├── Generation/
│   │   ├── Gallery/
│   │   └── Settings/
│   ├── Services/
│   │   ├── APIService.swift
│   │   ├── AuthService.swift
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

1. **Always prioritize child safety** in all features and implementations
2. **Follow iOS 18+ best practices** - fetch latest iOS development patterns and APIs
3. **Implement proper parental controls** for all features that involve children
4. **Ensure COPPA compliance** in all data handling and privacy features
5. **Design for accessibility** - support children with different abilities
6. **Focus on educational value** while maintaining fun and engagement
7. **Test on actual devices** children would use, not just latest hardware
8. **Follow Apple's Human Interface Guidelines** specifically for family apps

When implementing any feature, always consider:
- Is this safe for a 4-year-old to use independently?
- Does this require parental oversight or approval?
- Is the UI simple enough for young children?
- Does this provide educational or creative value?
- Is this compliant with children's privacy laws?

This app should be a trusted digital creative companion for families, promoting safe, educational, and joyful creative expression for children.