import Foundation
import Combine

class ProductCategoriesService: ObservableObject {
    static let shared = ProductCategoriesService()
    
    private let baseURL = AppConfig.API.baseURL
    @Published var products: [ProductCategory] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private init() {}
    
    // MARK: - Product Categories Management
    
    /// Get all product categories with their options from /api/categories/products
    func getProductCategories() async throws -> ProductCategoriesResponse {
        let endpoint = "\(baseURL)/categories/products"
        
        guard let url = URL(string: endpoint) else {
            throw ProductError.invalidURL
        }
        
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw ProductError.noToken
        }
        
        print("📦 ProductCategoriesService: Loading product categories")
        print("🔗 Request URL: \(endpoint)")
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        #if DEBUG
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 Products Response: \(responseString)")
        }
        #endif
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProductError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            // Try to decode API error message first, fallback to generic error
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw ProductError.serverError(apiError.userMessage)
            } else {
                throw ProductError.httpError(httpResponse.statusCode)
            }
        }
        
        let productsResponse = try JSONDecoder().decode(ProductCategoriesResponse.self, from: data)
        print("✅ ProductCategoriesService: Successfully decoded \(productsResponse.products.count) product categories")
        
        #if DEBUG
        for product in productsResponse.products {
            print("📦 Product: \(product.name) - Type: \(product.productType)")
        }
        #endif
        
        return productsResponse
    }
    
    /// Load products into published property
    func loadProducts() async {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            let response = try await getProductCategories()
            await MainActor.run {
                products = response.products
                isLoading = false
            }
            print("✅ ProductCategoriesService: Loaded \(response.products.count) product categories")
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
            print("❌ ProductCategoriesService: Error loading products - \(error)")
        }
    }
    
    /// Clear loaded products
    func clearProducts() {
        products.removeAll()
        error = nil
    }
    
    /// Find product by ID
    func getProduct(by id: String) -> ProductCategory? {
        return products.first { $0.id == id }
    }
    
    /// Get products by type (e.g., "book")
    func getProducts(by type: String) -> [ProductCategory] {
        return products.filter { $0.productType == type }
    }
}