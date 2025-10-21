# SketchWink iOS App Development Guide

> **Complete API Reference & Implementation Guide for iOS 18+**  
> Last Updated: September 2025

## 📱 **App Overview**

SketchWink is an AI-powered creative platform that generates coloring pages, stickers, wallpapers, and mandalas. Built with family-friendly features, enterprise-grade subscriptions, and professional AI models.

### **Core Value Proposition**
- 🤖 **AI-Generated Content**: Infinite variety using Seedream-4 and FLUX models
- 👨‍👩‍👧‍👦 **Family Profiles**: Netflix-style profile management with PIN protection
- 💳 **Flexible Subscriptions**: 9 tiers from free to business with advanced features
- 🎨 **Professional Quality**: Ultra-HD exports with commercial licensing
- 📱 **Native Experience**: Optimized for iOS with modern SwiftUI architecture

---

## 🚀 **Quick Start Integration**

### **Base Configuration**
```swift
struct APIConfig {
    static let baseURL = "http://localhost:3000/api"  // Development
    // static let baseURL = "https://api.sketchwink.com/api"  // Production
    
    static let timeout: TimeInterval = 30
    static let maxRetries = 3
}
```

### **Authentication Headers**
```swift
func authHeaders(token: String) -> [String: String] {
    return [
        "Authorization": "Bearer \(token)",
        "Content-Type": "application/json",
        "Accept": "application/json"
    ]
}
```

---

## 🔐 **Authentication Flow**

### **1. User Registration**
```swift
struct SignUpRequest: Codable {
    let email: String
    let password: String
    let name: String
}

struct SignUpResponse: Codable {
    let success: Bool
    let message: String
    let requiresVerification: Bool
}

// POST /api/auth/sign-up
func signUp(email: String, password: String, name: String) async throws -> SignUpResponse {
    let request = SignUpRequest(email: email, password: password, name: name)
    let data = try JSONEncoder().encode(request)
    
    var urlRequest = URLRequest(url: URL(string: "\(APIConfig.baseURL)/auth/sign-up")!)
    urlRequest.httpMethod = "POST"
    urlRequest.httpBody = data
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let (responseData, _) = try await URLSession.shared.data(for: urlRequest)
    return try JSONDecoder().decode(SignUpResponse.self, from: responseData)
}
```

### **2. Email Verification**
```swift
struct VerifyOTPRequest: Codable {
    let email: String
    let code: String
}

struct VerifyOTPResponse: Codable {
    let success: Bool
    let message: String
    let user: User?
    let welcomeTokens: Int?  // 3 free tokens granted
}

// POST /api/verify-otp
func verifyOTP(email: String, code: String) async throws -> VerifyOTPResponse {
    let request = VerifyOTPRequest(email: email, code: code)
    // Implementation similar to signUp...
}
```

### **3. Sign In**
```swift
struct SignInRequest: Codable {
    let email: String
    let password: String
}

struct SignInResponse: Codable {
    let user: User
    let session: Session
}

struct User: Codable {
    let id: String
    let email: String
    let name: String
    let emailVerified: Bool
    let role: String
    let promptEnhancementEnabled: Bool
}

struct Session: Codable {
    let id: String
    let token: String
    let expiresAt: String
}

// POST /api/auth/sign-in
func signIn(email: String, password: String) async throws -> SignInResponse {
    // Store token in Keychain for security
    // Implementation...
}
```

### **4. Token Storage (Security Best Practice)**
```swift
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    func store(token: String) throws {
        let data = token.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "sketchwink_token",
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.unableToStore
        }
    }
    
    func retrieve() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "sketchwink_token",
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
}
```

---

## 👨‍👩‍👧‍👦 **Family Profile System**

### **1. Get Available Profiles**
```swift
struct FamilyProfile: Codable {
    let id: String
    let name: String
    let avatar: String?
    let isDefault: Bool
    let canMakePurchases: Bool
    let canUseCustomContentTypes: Bool
    let hasPin: Bool  // PIN existence (actual PIN never exposed)
}

// GET /api/profiles/available
func getAvailableProfiles() async throws -> [FamilyProfile] {
    guard let token = try KeychainManager.shared.retrieve() else {
        throw AuthError.noToken
    }
    
    var request = URLRequest(url: URL(string: "\(APIConfig.baseURL)/profiles/available")!)
    request.httpMethod = "GET"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    
    let (data, _) = try await URLSession.shared.data(for: request)
    return try JSONDecoder().decode([FamilyProfile].self, from: data)
}
```

### **2. Profile Selection with PIN**
```swift
struct SelectProfileRequest: Codable {
    let profileId: String
    let pin: String?  // Required if profile has PIN protection
}

struct SelectProfileResponse: Codable {
    let success: Bool
    let message: String
    let selectedProfile: FamilyProfile?
}

// POST /api/profiles/select
func selectProfile(profileId: String, pin: String?) async throws -> SelectProfileResponse {
    let request = SelectProfileRequest(profileId: profileId, pin: pin)
    // Implementation with PIN verification...
}
```

### **3. Profile Management (Admin Only)**
```swift
struct CreateProfileRequest: Codable {
    let name: String
    let avatar: String?
    let pin: String?
    let canMakePurchases: Bool
    let canUseCustomContentTypes: Bool
}

// POST /api/family-profiles (Admin only)
func createProfile(_ request: CreateProfileRequest) async throws -> FamilyProfile {
    // Admin user can create up to maxFamilyProfiles based on subscription
}

// PUT /api/family-profiles/{id} (Admin only)
func updateProfile(id: String, _ request: CreateProfileRequest) async throws -> FamilyProfile {
    // Update profile settings including PIN changes
}

// DELETE /api/family-profiles/{id} (Admin only)
func deleteProfile(id: String) async throws {
    // Delete profile with safety checks (cannot delete if only profile)
}
```

---

## 💰 **Subscription Management**

### **1. Get Subscription Plans**
```swift
struct SubscriptionPlan: Codable {
    let id: String  // free, basic_monthly, pro_yearly, etc.
    let name: String
    let description: String
    let monthlyTokens: Int
    let price: Double  // In cents
    let currency: String
    let features: SubscriptionFeatures
    let platform: String  // "web", "ios", "both"
    let appleProductId: String?
    let stripePriceId: String?
    let trialDays: Int
    let isActive: Bool
    let sortOrder: Int
    let hasQualitySelector: Bool
    let hasCommercialLicense: Bool
    let hasModelSelector: Bool
    let hasImageUpload: Bool
    let maxFamilyProfiles: Int
    let isFreeTier: Bool
}

struct SubscriptionFeatures: Codable {
    let allStyles: Bool
    let familyProfiles: Bool
    let qualitySelector: Bool
    let modelSelector: Bool
    let commercialLicense: Bool
    let prioritySupport: Bool
    let tokenRollover: String?
    let savings: String?
}

// GET /api/subscription-plans
func getSubscriptionPlans() async throws -> [SubscriptionPlan] {
    // Returns 9 plans: free + 8 paid tiers
}
```

### **2. Current User Status**
```swift
struct TokenBalance: Codable {
    let subscriptionTokens: Int
    let purchasedTokens: Int
    let totalTokens: Int
    let lastSubscriptionRefresh: String?
    let maxRollover: Int
    let currentPlan: SubscriptionPlan?
}

struct FeatureAccess: Codable {
    let hasQualitySelector: Bool
    let hasCommercialLicense: Bool
    let hasModelSelector: Bool
    let hasImageUpload: Bool
    let maxFamilyProfiles: Int
    let canCreateMoreProfiles: Bool
    let currentProfileCount: Int
}

// GET /api/user/token-balance
func getTokenBalance() async throws -> TokenBalance {
    // Get current token balance with rollover information
}

// GET /api/user/feature-access
func getFeatureAccess() async throws -> FeatureAccess {
    // Get feature permissions based on subscription
}
```

### **3. iOS In-App Purchase Integration**
```swift
import StoreKit

class SubscriptionManager: ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedSubscriptions: Set<Product> = []
    
    private let productIDs = [
        "com.yourapp.basic.monthly",
        "com.yourapp.basic.yearly", 
        "com.yourapp.pro.monthly",
        "com.yourapp.pro.yearly",
        "com.yourapp.max.monthly",
        "com.yourapp.max.yearly",
        "com.yourapp.business.monthly",
        "com.yourapp.business.yearly"
    ]
    
    func loadProducts() async {
        do {
            products = try await Product.products(for: productIDs)
        } catch {
            print("Failed to load products: \(error)")
        }
    }
    
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                // Send receipt to backend for verification
                try await verifyPurchase(transaction: transaction)
                await transaction.finish()
            case .unverified:
                throw SubscriptionError.unverifiedPurchase
            }
        case .userCancelled:
            break
        case .pending:
            // Handle pending purchase
            break
        @unknown default:
            break
        }
    }
    
    func verifyPurchase(transaction: Transaction) async throws {
        // Send transaction data to backend for verification
        // Backend will validate with Apple and activate subscription
    }
}
```

---

## 🎨 **AI Generation System**

### **1. Get Categories and Options**
```swift
struct GenerationCategory: Codable {
    let id: String  // "coloring_pages", "stickers", "wallpapers", "mandalas"
    let name: String
    let description: String
    let icon: String
    let tokenCost: Int
    let multipleOptions: Bool
    let maxOptionsCount: Int
    let isActive: Bool
    let isDefault: Bool
    let sortOrder: Int
}

struct GenerationOption: Codable {
    let id: String
    let categoryId: String
    let name: String
    let description: String
    let promptTemplate: String
    let style: String
    let isActive: Bool
    let isDefault: Bool
    let sortOrder: Int
}

struct CategoryWithOptions: Codable {
    let category: GenerationCategory
    let options: [GenerationOption]
}

// GET /api/categories/with-options
func getCategoriesWithOptions() async throws -> [CategoryWithOptions] {
    // Returns all 4 categories with their options:
    // - Coloring Pages: 4 options (Cartoon, Japanese, Realistic, Biblical)
    // - Stickers: 5 options (Animals, Food, Emoji, Nature, Adventure)  
    // - Wallpapers: 8 options (Fantasy, Adventure, Animals, Rainbow, Space, Nature, Characters, Patterns)
    // - Mandalas: 6 options (Simple, Geometric, Nature, Animal, Complex, Floral)
}
```

### **2. Create Generation**
```swift
struct CreateGenerationRequest: Codable {
    let categoryId: String
    let optionId: String
    let prompt: String
    let quality: String?     // "standard", "high", "ultra" (requires subscription)
    let dimensions: String?  // "1:1", "2:3", "3:2", "a4"
    let maxImages: Int?      // 1-4 images per generation
    let model: String?       // "seedream", "gemini" (all plans), "flux" (Business+ only)
}

struct Generation: Codable {
    let id: String
    let status: String  // "processing", "completed", "failed"
    let categoryId: String
    let optionId: String
    let title: String
    let description: String
    let userPrompt: String
    let tokensUsed: Int
    let quality: String
    let dimensions: String
    let modelVersion: String
    let errorMessage: String?
    let images: [GeneratedImage]?
    let createdAt: String
    let updatedAt: String
}

struct GeneratedImage: Codable {
    let id: String
    let imageUrl: String  // Permanent Cloudflare R2 URL
    let optionIndex: Int  // 0-3 for multiple variations
    let isFavorite: Bool
    let originalUserPrompt: String
    let enhancedPrompt: String?
    let wasEnhanced: Bool
    let modelUsed: String
    let qualityUsed: String
    let dimensionsUsed: String
    let createdAt: String
}

// POST /api/generations
func createGeneration(_ request: CreateGenerationRequest) async throws -> Generation {
    // Creates AI generation with prompt enhancement
    // Returns immediately with "processing" status
    // Poll for completion using getGeneration()
}
```

### **3. Monitor Generation Progress**
```swift
// GET /api/generations/{id}
func getGeneration(id: String) async throws -> Generation {
    // Poll every 2-3 seconds while status is "processing"
    // Status changes to "completed" with image URLs or "failed" with error
}

// Example polling implementation
func pollGeneration(id: String) async throws -> Generation {
    while true {
        let generation = try await getGeneration(id: id)
        
        switch generation.status {
        case "completed":
            return generation
        case "failed":
            throw GenerationError.failed(generation.errorMessage ?? "Unknown error")
        case "processing":
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            continue
        default:
            throw GenerationError.unknownStatus(generation.status)
        }
    }
}
```

### **4. Prompt Enhancement**
```swift
struct PromptEnhanceRequest: Codable {
    let originalPrompt: String
    let categoryId: String
    let optionId: String
}

struct PromptEnhanceResponse: Codable {
    let originalPrompt: String
    let enhancedPrompt: String
    let wasEnhanced: Bool
}

// POST /api/prompt/enhance
func enhancePrompt(_ request: PromptEnhanceRequest) async throws -> PromptEnhanceResponse {
    // Uses OpenAI GPT-4o-mini to enhance user prompts for better AI generation
    // Optional feature controlled by user preference
}
```

---

## 📱 **Image Management & Collections**

### **1. Get User Images with Filtering**
```swift
struct ImageFilter {
    let page: Int?
    let limit: Int?
    let category: String?
    let favorites: Bool?
    let collection: String?
    let search: String?
    let sortBy: String?     // "createdAt", "favorite", "category"
    let sortOrder: String?  // "asc", "desc"
}

struct ImagesResponse: Codable {
    let images: [GeneratedImage]
    let pagination: PaginationInfo
    let totalCount: Int
}

struct PaginationInfo: Codable {
    let currentPage: Int
    let totalPages: Int
    let hasNext: Bool
    let hasPrev: Bool
}

// GET /api/images with filtering
func getImages(filter: ImageFilter) async throws -> ImagesResponse {
    var components = URLComponents(string: "\(APIConfig.baseURL)/images")!
    var queryItems: [URLQueryItem] = []
    
    if let page = filter.page {
        queryItems.append(URLQueryItem(name: "page", value: "\(page)"))
    }
    if let limit = filter.limit {
        queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
    }
    if let category = filter.category {
        queryItems.append(URLQueryItem(name: "category", value: category))
    }
    if let favorites = filter.favorites {
        queryItems.append(URLQueryItem(name: "favorites", value: "\(favorites)"))
    }
    // Add other filter parameters...
    
    components.queryItems = queryItems
    
    // Make request with auth headers...
}
```

### **2. Download Images with Format Conversion**
```swift
enum ImageFormat: String, CaseIterable {
    case jpg = "jpg"
    case png = "png" 
    case webp = "webp"
    case pdf = "pdf"
}

// GET /api/images/{id}/download
func downloadImage(id: String, format: ImageFormat, quality: Int = 95) async throws -> Data {
    let url = "\(APIConfig.baseURL)/images/\(id)/download?format=\(format.rawValue)&quality=\(quality)"
    
    guard let token = try KeychainManager.shared.retrieve() else {
        throw AuthError.noToken
    }
    
    var request = URLRequest(url: URL(string: url)!)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    
    let (data, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        throw NetworkError.downloadFailed
    }
    
    return data
}

// Save to Photos Library
func saveToPhotos(imageData: Data) async throws {
    guard let uiImage = UIImage(data: imageData) else {
        throw ImageError.invalidData
    }
    
    try await PHPhotoLibrary.shared().performChanges {
        PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
    }
}
```

### **3. Favorites Management**
```swift
// PATCH /api/generated-images/{id}/favorite
func toggleFavorite(imageId: String) async throws {
    guard let token = try KeychainManager.shared.retrieve() else {
        throw AuthError.noToken
    }
    
    var request = URLRequest(url: URL(string: "\(APIConfig.baseURL)/generated-images/\(imageId)/favorite")!)
    request.httpMethod = "PATCH"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    
    let (_, response) = try await URLSession.shared.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        throw NetworkError.favoriteFailed
    }
}

// POST /api/images/bulk-favorite
func bulkFavorite(imageIds: [String], favorite: Bool) async throws {
    let request = [
        "imageIds": imageIds,
        "favorite": favorite
    ]
    // Implementation...
}
```

### **4. Collections Management**
```swift
struct UserCollection: Codable {
    let id: String
    let userId: String
    let name: String
    let description: String?
    let color: String    // Hex color for UI
    let icon: String     // Emoji icon
    let isPublic: Bool
    let sortOrder: Int
    let imageCount: Int?
    let createdAt: String
    let updatedAt: String
}

struct CreateCollectionRequest: Codable {
    let name: String
    let description: String?
    let color: String
    let icon: String
}

// GET /api/collections
func getCollections() async throws -> [UserCollection]

// POST /api/collections  
func createCollection(_ request: CreateCollectionRequest) async throws -> UserCollection

// PUT /api/collections/{id}
func updateCollection(id: String, _ request: CreateCollectionRequest) async throws -> UserCollection

// DELETE /api/collections/{id}
func deleteCollection(id: String) async throws

// POST /api/collections/{id}/images
func addImageToCollection(collectionId: String, imageId: String, notes: String?) async throws

// DELETE /api/collections/{id}/images/{imageId}
func removeImageFromCollection(collectionId: String, imageId: String) async throws

// POST /api/collections/{id}/bulk-add
func bulkAddToCollection(collectionId: String, imageIds: [String]) async throws
```

---

## 📊 **Analytics & User Dashboard**

### **1. User Analytics**
```swift
struct UserAnalytics: Codable {
    let overview: AnalyticsOverview
    let categoryBreakdown: [CategoryStats]
    let monthlyActivity: [MonthlyActivity]
    let topPrompts: [PromptStats]
    let modelUsage: [ModelStats]
}

struct AnalyticsOverview: Codable {
    let totalImages: Int
    let totalGenerations: Int
    let totalCollections: Int
    let totalFavorites: Int
    let tokensUsed: Int
}

struct CategoryStats: Codable {
    let category: String
    let count: Int
    let percentage: Double
}

struct MonthlyActivity: Codable {
    let month: String      // "2025-01"
    let generations: Int
    let images: Int
}

struct PromptStats: Codable {
    let prompt: String
    let usageCount: Int
}

struct ModelStats: Codable {
    let model: String      // "seedream", "gemini", "flux"
    let count: Int
    let percentage: Double
}

// GET /api/analytics
func getUserAnalytics() async throws -> UserAnalytics {
    // Comprehensive analytics for user dashboard
}
```

---

## 🎨 **Simple Coloring Feature Implementation**

### **SwiftUI Coloring Canvas**
```swift
import SwiftUI

struct ColoringView: View {
    let mandalaImage: UIImage
    @State private var drawnPaths: [DrawnPath] = []
    @State private var currentPath = Path()
    @State private var selectedColor = Color.red
    @State private var brushSize: CGFloat = 8.0
    @State private var isDrawing = false
    
    var body: some View {
        VStack {
            // Color palette
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ColorPalette.defaultColors, id: \.self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(selectedColor == color ? Color.black : Color.clear, lineWidth: 3)
                            )
                            .onTapGesture {
                                selectedColor = color
                            }
                    }
                }
                .padding(.horizontal)
            }
            
            // Brush size slider
            VStack {
                Text("Brush Size: \(Int(brushSize))")
                    .font(.caption)
                
                Slider(value: $brushSize, in: 2...20, step: 1)
                    .padding(.horizontal)
            }
            
            // Drawing canvas
            ZStack {
                // Background mandala
                Image(uiImage: mandalaImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .allowsHitTesting(false)
                
                // Drawing overlay
                Canvas { context, size in
                    for path in drawnPaths {
                        context.stroke(
                            path.path,
                            with: .color(path.color),
                            style: StrokeStyle(
                                lineWidth: path.lineWidth,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                    }
                    
                    // Current drawing path
                    if isDrawing {
                        context.stroke(
                            currentPath,
                            with: .color(selectedColor),
                            style: StrokeStyle(
                                lineWidth: brushSize,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDrawing {
                                isDrawing = true
                                currentPath = Path()
                                currentPath.move(to: value.location)
                            } else {
                                currentPath.addLine(to: value.location)
                            }
                        }
                        .onEnded { _ in
                            finishStroke()
                        }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Controls
            HStack(spacing: 20) {
                Button("Undo") {
                    undoLastStroke()
                }
                .disabled(drawnPaths.isEmpty)
                
                Button("Clear All") {
                    clearAll()
                }
                .disabled(drawnPaths.isEmpty)
                
                Button("Save") {
                    saveColoredImage()
                }
                .disabled(drawnPaths.isEmpty)
            }
            .padding()
        }
    }
    
    private func finishStroke() {
        guard isDrawing else { return }
        
        drawnPaths.append(DrawnPath(
            path: currentPath,
            color: selectedColor,
            lineWidth: brushSize
        ))
        
        currentPath = Path()
        isDrawing = false
    }
    
    private func undoLastStroke() {
        guard !drawnPaths.isEmpty else { return }
        drawnPaths.removeLast()
    }
    
    private func clearAll() {
        drawnPaths.removeAll()
        currentPath = Path()
        isDrawing = false
    }
    
    private func saveColoredImage() {
        // Render the complete colored image
        let renderer = ImageRenderer(content: renderableContent())
        renderer.scale = 3.0 // High quality
        
        if let uiImage = renderer.uiImage {
            // Save to Photos Library
            UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
        }
    }
    
    @ViewBuilder
    private func renderableContent() -> some View {
        ZStack {
            Image(uiImage: mandalaImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
            
            Canvas { context, size in
                for path in drawnPaths {
                    context.stroke(
                        path.path,
                        with: .color(path.color),
                        style: StrokeStyle(
                            lineWidth: path.lineWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                }
            }
        }
    }
}

struct DrawnPath {
    let path: Path
    let color: Color
    let lineWidth: CGFloat
}

struct ColorPalette {
    static let defaultColors: [Color] = [
        .red, .orange, .yellow, .green, .blue, .purple, .pink,
        .brown, .gray, .black,
        Color(red: 1, green: 0.6, blue: 0.8),      // Light pink
        Color(red: 0.6, green: 1, blue: 0.6),      // Light green
        Color(red: 0.6, green: 0.8, blue: 1),      // Light blue
        Color(red: 1, green: 1, blue: 0.6),        // Light yellow
        Color(red: 0.8, green: 0.6, blue: 1),      // Light purple
    ]
}
```

---

## 🔄 **Recommended App Architecture**

### **1. MVVM with Combine**
```swift
import SwiftUI
import Combine

// View Model for Generation
class GenerationViewModel: ObservableObject {
    @Published var categories: [CategoryWithOptions] = []
    @Published var currentGeneration: Generation?
    @Published var isGenerating = false
    @Published var error: Error?
    
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    
    init(apiService: APIService = .shared) {
        self.apiService = apiService
    }
    
    func loadCategories() {
        apiService.getCategoriesWithOptions()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        self.error = error
                    }
                },
                receiveValue: { categories in
                    self.categories = categories
                }
            )
            .store(in: &cancellables)
    }
    
    func generateContent(request: CreateGenerationRequest) {
        isGenerating = true
        
        apiService.createGeneration(request)
            .flatMap { generation in
                self.pollForCompletion(generationId: generation.id)
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    self.isGenerating = false
                    if case .failure(let error) = completion {
                        self.error = error
                    }
                },
                receiveValue: { generation in
                    self.currentGeneration = generation
                }
            )
            .store(in: &cancellables)
    }
    
    private func pollForCompletion(generationId: String) -> AnyPublisher<Generation, Error> {
        Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .flatMap { _ in
                self.apiService.getGeneration(id: generationId)
            }
            .first { generation in
                generation.status != "processing"
            }
            .eraseToAnyPublisher()
    }
}
```

### **2. API Service Layer**
```swift
protocol APIServiceProtocol {
    func signIn(email: String, password: String) async throws -> SignInResponse
    func getCategoriesWithOptions() async throws -> [CategoryWithOptions]
    func createGeneration(_ request: CreateGenerationRequest) async throws -> Generation
    func getGeneration(id: String) async throws -> Generation
    // ... other methods
}

class APIService: APIServiceProtocol {
    static let shared = APIService()
    
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        
        // Configure date formatting
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        decoder.dateDecodingStrategy = .formatted(dateFormatter)
    }
    
    private func makeRequest<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: Encodable? = nil,
        requiresAuth: Bool = true
    ) async throws -> T {
        
        guard let url = URL(string: "\(APIConfig.baseURL)\(endpoint)") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        // Add authentication if required
        if requiresAuth {
            guard let token = try KeychainManager.shared.retrieve() else {
                throw AuthError.noToken
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add body if provided
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw NetworkError.httpError(httpResponse.statusCode)
        }
        
        return try decoder.decode(T.self, from: data)
    }
}

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case PATCH = "PATCH"
    case DELETE = "DELETE"
}
```

### **3. Data Models**
```swift
// Organize models by feature
struct AuthModels {
    // All auth-related models
}

struct GenerationModels {
    // All generation-related models  
}

struct SubscriptionModels {
    // All subscription-related models
}

struct CollectionModels {
    // All collection-related models
}
```

---

## 🚨 **Error Handling**

### **Custom Error Types**
```swift
enum AuthError: LocalizedError {
    case noToken
    case invalidCredentials
    case emailNotVerified
    case accountLocked
    
    var errorDescription: String? {
        switch self {
        case .noToken:
            return "Authentication token not found"
        case .invalidCredentials:
            return "Invalid email or password"
        case .emailNotVerified:
            return "Please verify your email address"
        case .accountLocked:
            return "Account has been locked"
        }
    }
}

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError
    case noConnection
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code):
            return "Server error: \(code)"
        case .decodingError:
            return "Failed to decode response"
        case .noConnection:
            return "No internet connection"
        }
    }
}

enum GenerationError: LocalizedError {
    case insufficientTokens
    case invalidCategory
    case generationFailed(String)
    case subscriptionRequired
    
    var errorDescription: String? {
        switch self {
        case .insufficientTokens:
            return "Not enough tokens to generate content"
        case .invalidCategory:
            return "Invalid content category"
        case .generationFailed(let message):
            return "Generation failed: \(message)"
        case .subscriptionRequired:
            return "This feature requires a subscription"
        }
    }
}
```

---

## 📱 **UI/UX Recommendations**

### **1. Onboarding Flow**
```swift
struct OnboardingView: View {
    @State private var currentPage = 0
    
    let pages = [
        OnboardingPage(
            title: "Create Amazing Art",
            description: "Generate unlimited coloring pages, stickers, and wallpapers with AI",
            image: "onboarding1"
        ),
        OnboardingPage(
            title: "Family Friendly",
            description: "Safe profiles for every family member with parental controls",
            image: "onboarding2"
        ),
        OnboardingPage(
            title: "Professional Quality",
            description: "Ultra-HD exports with commercial licensing available",
            image: "onboarding3"
        )
    ]
    
    var body: some View {
        TabView(selection: $currentPage) {
            ForEach(0..<pages.count, id: \.self) { index in
                OnboardingPageView(page: pages[index])
                    .tag(index)
            }
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}
```

### **2. Category Selection**
```swift
struct CategorySelectionView: View {
    let categories: [CategoryWithOptions]
    @Binding var selectedCategory: CategoryWithOptions?
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ForEach(categories, id: \.category.id) { categoryWithOptions in
                CategoryCard(
                    category: categoryWithOptions.category,
                    isSelected: selectedCategory?.category.id == categoryWithOptions.category.id
                ) {
                    selectedCategory = categoryWithOptions
                }
            }
        }
        .padding()
    }
}

struct CategoryCard: View {
    let category: GenerationCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Text(category.icon)
                .font(.system(size: 40))
            
            Text(category.name)
                .font(.headline)
                .multilineTextAlignment(.center)
            
            Text(category.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding()
        .frame(height: 140)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
        )
        .onTapGesture(perform: action)
    }
}
```

### **3. Generation Progress**
```swift
struct GenerationProgressView: View {
    let progress: GenerationProgress
    
    var body: some View {
        VStack(spacing: 20) {
            // Progress animation
            LottieView(animation: "ai_generating")
                .frame(width: 200, height: 200)
            
            VStack(spacing: 8) {
                Text(progress.status)
                    .font(.headline)
                
                Text(progress.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Progress bar
            ProgressView(value: progress.percentage)
                .progressViewStyle(LinearProgressViewStyle())
                .frame(width: 200)
            
            Text("\(Int(progress.percentage * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct GenerationProgress {
    let status: String
    let description: String
    let percentage: Double
    
    static let states = [
        GenerationProgress(status: "Enhancing Prompt", description: "Making your idea even better", percentage: 0.2),
        GenerationProgress(status: "Generating Art", description: "AI is creating your masterpiece", percentage: 0.6),
        GenerationProgress(status: "Optimizing Images", description: "Preparing high-quality downloads", percentage: 0.9),
        GenerationProgress(status: "Complete!", description: "Your art is ready", percentage: 1.0)
    ]
}
```

---

## 🔧 **Testing Strategy**

### **1. Unit Tests**
```swift
import XCTest
@testable import SketchWink

class APIServiceTests: XCTestCase {
    var apiService: APIService!
    var mockSession: MockURLSession!
    
    override func setUpWithError() throws {
        mockSession = MockURLSession()
        apiService = APIService(session: mockSession)
    }
    
    func testSignInSuccess() async throws {
        // Given
        let expectedResponse = SignInResponse(
            user: User(id: "123", email: "test@example.com", name: "Test User"),
            session: Session(id: "session123", token: "token123", expiresAt: "2025-12-31")
        )
        
        mockSession.data = try JSONEncoder().encode(expectedResponse)
        mockSession.response = HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When
        let result = try await apiService.signIn(email: "test@example.com", password: "password")
        
        // Then
        XCTAssertEqual(result.user.email, "test@example.com")
        XCTAssertEqual(result.session.token, "token123")
    }
}

class MockURLSession: URLSession {
    var data: Data?
    var response: URLResponse?
    var error: Error?
    
    override func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let error = error {
            throw error
        }
        
        return (data ?? Data(), response ?? URLResponse())
    }
}
```

### **2. Integration Tests**
```swift
class IntegrationTests: XCTestCase {
    func testCompleteGenerationFlow() async throws {
        // Test the full flow from authentication to generation completion
        let apiService = APIService()
        
        // 1. Sign in
        let signInResponse = try await apiService.signIn(
            email: "test@example.com",
            password: "password"
        )
        
        // 2. Get categories
        let categories = try await apiService.getCategoriesWithOptions()
        XCTAssertFalse(categories.isEmpty)
        
        // 3. Create generation
        let request = CreateGenerationRequest(
            categoryId: "mandalas",
            optionId: categories.first!.options.first!.id,
            prompt: "test mandala",
            quality: "standard",
            dimensions: "1:1",
            maxImages: 1,
            model: "seedream"
        )
        
        let generation = try await apiService.createGeneration(request)
        XCTAssertEqual(generation.status, "processing")
        
        // 4. Poll for completion (with timeout)
        let completedGeneration = try await waitForGeneration(id: generation.id)
        XCTAssertEqual(completedGeneration.status, "completed")
        XCTAssertFalse(completedGeneration.images?.isEmpty ?? true)
    }
    
    private func waitForGeneration(id: String, timeout: TimeInterval = 60) async throws -> Generation {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            let generation = try await APIService.shared.getGeneration(id: id)
            
            if generation.status == "completed" {
                return generation
            } else if generation.status == "failed" {
                throw GenerationError.generationFailed(generation.errorMessage ?? "Unknown error")
            }
            
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        }
        
        throw GenerationError.generationFailed("Timeout waiting for generation")
    }
}
```

---

## 🚀 **Deployment & Distribution**

### **1. Build Configurations**
```swift
// Debug.xcconfig
API_BASE_URL = http://localhost:3000/api
LOG_LEVEL = DEBUG

// Release.xcconfig  
API_BASE_URL = https://api.sketchwink.com/api
LOG_LEVEL = ERROR

// In Info.plist
<key>APIBaseURL</key>
<string>$(API_BASE_URL)</string>
```

### **2. App Store Guidelines Compliance**
```swift
// In-App Purchase Configuration
class StoreKitManager {
    // Ensure compliance with App Store guidelines
    // - Clearly display subscription terms
    // - Honor Apple's refund policies
    // - Provide easy cancellation
    // - Display pricing in user's local currency
}

// Content Policy Compliance
struct ContentPolicy {
    // - All AI-generated content is family-friendly
    // - User prompts are filtered for inappropriate content
    // - Biblical content follows religious guidelines
    // - No violent or inappropriate imagery
}
```

### **3. Performance Optimization**
```swift
// Image caching for offline viewing
class ImageCache {
    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    
    func cacheImage(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
        
        // Also save to disk for persistence
        if let data = image.jpegData(compressionQuality: 0.8) {
            let url = getCacheURL(for: key)
            try? data.write(to: url)
        }
    }
    
    func getImage(forKey key: String) -> UIImage? {
        // Check memory cache first
        if let cachedImage = cache.object(forKey: key as NSString) {
            return cachedImage
        }
        
        // Check disk cache
        let url = getCacheURL(for: key)
        if let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            cache.setObject(image, forKey: key as NSString)
            return image
        }
        
        return nil
    }
}
```

---

## 🎯 **Success Metrics & Analytics**

### **1. Key Performance Indicators**
```swift
struct AppAnalytics {
    // User Engagement
    let dailyActiveUsers: Int
    let monthlyActiveUsers: Int
    let sessionDuration: TimeInterval
    let generationsPerSession: Double
    
    // Subscription Metrics
    let conversionRate: Double      // Free to paid conversion
    let churnRate: Double          // Monthly subscription churn
    let averageRevenuePerUser: Double
    
    // Content Performance
    let mostPopularCategories: [String]
    let averageGenerationTime: TimeInterval
    let userSatisfactionRating: Double
    
    // Technical Performance
    let crashRate: Double
    let apiResponseTime: TimeInterval
    let imageLoadTime: TimeInterval
}
```

### **2. A/B Testing Framework**
```swift
class ABTestManager {
    func getVariant(for experiment: String) -> String {
        // Implement feature flag system for A/B testing
        // - Subscription page variants
        // - Onboarding flow variations
        // - UI/UX improvements
        // - Pricing strategy tests
    }
}
```

---

## 🎨 **Complete User Journey Map**

### **1. New User Flow**
```
1. App Launch → Onboarding (3 screens)
2. Sign Up → Email Verification (gets 3 free tokens)
3. Category Selection → Choose first content type
4. Generation Tutorial → Create first AI art
5. Result Sharing → Save/share first creation
6. Family Setup → Optional profile creation
7. Subscription Prompt → Upgrade when tokens low
```

### **2. Returning User Flow**
```
1. App Launch → Auto-signin with stored token
2. Profile Selection → Choose family member (if applicable)
3. Home Dashboard → Recent creations + quick actions
4. Content Creation → Streamlined generation flow
5. Gallery Management → Organize in collections
6. Advanced Features → Use subscription perks
```

### **3. Subscription User Journey**
```
Free Tier (3 tokens) → Basic ($9/mo) → Pro ($18/mo) → Max ($29/mo) → Business ($99/mo)
               ↓              ↓             ↓              ↓
     Limited features → Image upload → Family profiles → Quality + Commercial → All models + Priority
```

---

This comprehensive guide provides everything needed to build a professional iOS app that fully leverages the SketchWink platform. The backend is production-ready with enterprise features, and this guide ensures your iOS app can take full advantage of all capabilities while providing an excellent user experience.

Remember to implement proper error handling, follow iOS Human Interface Guidelines, and test thoroughly across different devices and iOS versions. The modular architecture described here will make it easy to add new features and maintain the codebase as the platform evolves.
