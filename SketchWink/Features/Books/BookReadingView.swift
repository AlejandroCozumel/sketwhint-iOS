import SwiftUI
import PDFKit

struct BookReadingView: View {
    let book: StoryBook
    
    @StateObject private var booksService = BooksService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var bookWithPages: BookWithPages?
    @State private var currentPageIndex = 0
    @State private var isLoading = true
    @State private var error: String?
    @State private var showingError = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if isLoading {
                    loadingView
                } else if let bookWithPages = bookWithPages {
                    readingView(bookWithPages)
                } else {
                    errorView
                }
            }
            .navigationTitle(book.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        ZStack {
                            Circle()
                                .fill(AppColors.surfaceLight)
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .stroke(AppColors.borderLight, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // PDF Download button
                        if let pdfUrl = book.pdfUrl {
                            Button(action: {
                                if let url = URL(string: pdfUrl) {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(AppColors.primaryBlue)
                                    Image(systemName: "arrow.down.doc.fill")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .frame(width: 36, height: 36)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Download PDF")
                        }

                        // Page counter (only show for image-based books, not PDFs)
                        if let bookWithPages = bookWithPages, book.pdfUrl == nil {
                            pageCounter(bookWithPages)
                        }
                    }
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onAppear {
            loadBookPages()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {}
            Button("Retry") {
                loadBookPages()
            }
        } message: {
            Text(error ?? "Failed to load book pages")
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: AppSpacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("Loading story book...")
                .font(AppTypography.bodyMedium)
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Error View
    private var errorView: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundColor(.white)
            
            Text("Failed to Load Book")
                .font(AppTypography.headlineMedium)
                .foregroundColor(.white)
            
            Text(error ?? "Unable to load the story book pages")
                .font(AppTypography.bodyMedium)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                loadBookPages()
            }
            .largeButtonStyle(backgroundColor: AppColors.primaryBlue)
            .childSafeTouchTarget()
        }
        .padding(AppSpacing.xl)
    }
    
    // MARK: - Reading View
    private func readingView(_ bookWithPages: BookWithPages) -> some View {
        VStack(spacing: 0) {
            // If PDF is available, show PDF viewer; otherwise show images
            if let pdfUrlString = book.pdfUrl,
               let pdfUrl = URL(string: pdfUrlString) {
                PDFKitView(url: pdfUrl)
            } else {
                // Fallback to image pages if PDF not available
                TabView(selection: $currentPageIndex) {
                    ForEach(Array(bookWithPages.pages.enumerated()), id: \.offset) { index, page in
                        BookPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

                // Navigation controls
                navigationControls(bookWithPages)
            }
        }
    }
    
    // MARK: - Navigation Controls
    private func navigationControls(_ bookWithPages: BookWithPages) -> some View {
        HStack {
            // Previous button with book-style icon
            Button {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    currentPageIndex = max(0, currentPageIndex - 1)
                }
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "book.closed")
                    Text("Previous")
                }
                .font(AppTypography.bodyMedium)
                .foregroundColor(currentPageIndex > 0 ? .white : .gray)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(.ultraThinMaterial.opacity(0.3), in: Capsule())
            }
            .disabled(currentPageIndex <= 0)
            .childSafeTouchTarget()
            
            Spacer()
            
            // Book spine indicator with page numbers
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(0..<min(bookWithPages.pages.count, 8), id: \.self) { index in
                        Rectangle()
                            .fill(index == currentPageIndex ? AppColors.primaryBlue : Color.gray.opacity(0.5))
                            .frame(width: index == currentPageIndex ? 6 : 4, height: 20)
                            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentPageIndex)
                    }
                    
                    if bookWithPages.pages.count > 8 {
                        Text("...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                Text("Page \(currentPageIndex + 1) of \(bookWithPages.pages.count)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            // Next button with book-style icon
            Button {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    currentPageIndex = min(bookWithPages.pages.count - 1, currentPageIndex + 1)
                }
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Text("Next")
                    Image(systemName: "book.closed")
                }
                .font(AppTypography.bodyMedium)
                .foregroundColor(currentPageIndex < bookWithPages.pages.count - 1 ? .white : .gray)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(.ultraThinMaterial.opacity(0.3), in: Capsule())
            }
            .disabled(currentPageIndex >= bookWithPages.pages.count - 1)
            .childSafeTouchTarget()
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.6), .clear],
                startPoint: .bottom,
                endPoint: .top
            )
        )
    }
    
    // MARK: - Page Counter
    private func pageCounter(_ bookWithPages: BookWithPages) -> some View {
        Text("Page \(currentPageIndex + 1) of \(bookWithPages.pages.count)")
            .font(AppTypography.captionLarge)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial.opacity(0.3), in: Capsule())
    }
    
    // MARK: - Data Loading
    private func loadBookPages() {
        isLoading = true
        error = nil
        
        Task {
            do {
                let result = try await booksService.getBookPages(bookId: book.id)
                
                await MainActor.run {
                    self.bookWithPages = result
                    self.isLoading = false
                    self.currentPageIndex = 0
                }
                
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                    self.showingError = true
                }
            }
        }
    }
}

// MARK: - PDF Viewer

struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical

        // Load PDF from URL
        if let document = PDFDocument(url: url) {
            pdfView.document = document
        }

        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        // Update if needed
    }
}

// MARK: - Book Page View

struct BookPageView: View {
    let page: BookPage
    
    @State private var imageScale: CGFloat = 1.0
    @State private var imageOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            AsyncImage(url: URL(string: page.imageUrl)) { imagePhase in
                switch imagePhase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(imageScale)
                        .offset(imageOffset)
                        .gesture(
                            SimultaneousGesture(
                                // Zoom gesture
                                MagnificationGesture()
                                    .onChanged { value in
                                        imageScale = max(1.0, min(3.0, value))
                                    }
                                    .onEnded { _ in
                                        withAnimation(.spring()) {
                                            if imageScale < 1.2 {
                                                imageScale = 1.0
                                                imageOffset = .zero
                                            }
                                        }
                                    },
                                
                                // Pan gesture (only when zoomed)
                                DragGesture()
                                    .onChanged { value in
                                        if imageScale > 1.0 {
                                            imageOffset = value.translation
                                        }
                                    }
                                    .onEnded { _ in
                                        withAnimation(.spring()) {
                                            // Reset offset if not significantly zoomed
                                            if imageScale < 1.2 {
                                                imageOffset = .zero
                                            } else {
                                                // Constrain offset to keep image in bounds
                                                let maxOffset = CGSize(
                                                    width: geometry.size.width * (imageScale - 1) / 2,
                                                    height: geometry.size.height * (imageScale - 1) / 2
                                                )
                                                
                                                imageOffset.width = max(-maxOffset.width, min(maxOffset.width, imageOffset.width))
                                                imageOffset.height = max(-maxOffset.height, min(maxOffset.height, imageOffset.height))
                                            }
                                        }
                                    }
                            )
                        )
                        .onTapGesture(count: 2) {
                            // Double-tap to zoom
                            withAnimation(.spring()) {
                                if imageScale == 1.0 {
                                    imageScale = 2.0
                                } else {
                                    imageScale = 1.0
                                    imageOffset = .zero
                                }
                            }
                        }
                        .clipped()
                
                case .failure(_):
                    VStack(spacing: AppSpacing.md) {
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("Failed to load page")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(.gray)
                    }
                
                case .empty:
                    VStack(spacing: AppSpacing.md) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.white)
                        
                        Text("Loading page \(page.pageNumber)...")
                            .font(AppTypography.captionLarge)
                            .foregroundColor(.white)
                    }
                
                @unknown default:
                    EmptyView()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

#Preview {
    BookReadingView(
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
        )
    )
}
