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
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var isDownloadingPDF = false
    @State private var isSharingPDF = false
    @State private var showingToast = false
    @State private var toastMessage = ""
    @State private var toastType: ToastModifier.ToastType = .success
    
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
                        // Page counter (only show for image-based books, not PDFs)
                        if let bookWithPages = bookWithPages, book.pdfUrl == nil {
                            pageCounter(bookWithPages)
                        }

                        // Show loading spinner when downloading or sharing, otherwise show menu
                        if isDownloadingPDF || isSharingPDF {
                            ProgressView()
                                .tint(AppColors.primaryBlue)
                                .frame(width: 36, height: 36)
                        } else {
                            // 3-dots menu
                            Menu {
                                // Download PDF button
                                if book.pdfUrl != nil {
                                    Button(action: {
                                        Task {
                                            await downloadPDFToDevice()
                                        }
                                    }) {
                                        Label("Download PDF", systemImage: "arrow.down.doc")
                                    }
                                }

                                // Share PDF button
                                if book.pdfUrl != nil {
                                    Button(action: {
                                        Task {
                                            await sharePDF()
                                        }
                                    }) {
                                        Label("Share PDF", systemImage: "square.and.arrow.up")
                                    }
                                }

                                // Delete button
                                Button(role: .destructive, action: {
                                    showingDeleteConfirmation = true
                                }) {
                                    Label("Delete Book", systemImage: "trash")
                                }
                                .tint(AppColors.errorRed)
                                .disabled(isDeleting)
                            } label: {
                                Image(systemName: "ellipsis.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(AppColors.primaryBlue)
                                    .frame(width: 36, height: 36)
                            }
                            .disabled(isDeleting)
                        }
                    }
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .toast(isShowing: $showingToast, message: toastMessage, type: toastType)
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
        .sheet(isPresented: $showingShareSheet) {
            if !shareItems.isEmpty {
                ActivityViewController(activityItems: shareItems)
            }
        }
        .alert("Delete Book", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteBook()
                }
            }
        } message: {
            Text("Are you sure you want to delete this book? This action cannot be undone.")
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
            // Always use image pages for the reading experience (PDF is available for download only)
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
    
    // MARK: - Navigation Controls
    private func navigationControls(_ bookWithPages: BookWithPages) -> some View {
        VStack(spacing: 0) {
            ZStack {
                // Page counter text (centered)
                Text("Page \(currentPageIndex + 1) of \(bookWithPages.pages.count)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))

                HStack {
                    // Previous button with arrow icon
                    Button {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            currentPageIndex = max(0, currentPageIndex - 1)
                        }
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(currentPageIndex > 0 ? .white : .gray)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.sm)
                            .background(.ultraThinMaterial.opacity(0.3), in: Capsule())
                    }
                    .disabled(currentPageIndex <= 0)
                    .childSafeTouchTarget()

                    Spacer()

                    // Next button with arrow icon
                    Button {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            currentPageIndex = min(bookWithPages.pages.count - 1, currentPageIndex + 1)
                        }
                    } label: {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(currentPageIndex < bookWithPages.pages.count - 1 ? .white : .gray)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.sm)
                            .background(.ultraThinMaterial.opacity(0.3), in: Capsule())
                    }
                    .disabled(currentPageIndex >= bookWithPages.pages.count - 1)
                    .childSafeTouchTarget()
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.md)
        }
        .background(
            LinearGradient(
                colors: [.black.opacity(0.6), .clear],
                startPoint: .bottom,
                endPoint: .top
            )
        )
        .ignoresSafeArea(edges: .bottom)
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

    // MARK: - Download PDF
    private func downloadPDFToDevice() async {
        guard !isDownloadingPDF else { return }
        guard let pdfUrlString = book.pdfUrl,
              let pdfURL = URL(string: pdfUrlString) else {
            await MainActor.run {
                toastMessage = "Invalid PDF URL"
                toastType = .error
                showingToast = true
            }
            return
        }

        await MainActor.run {
            isDownloadingPDF = true
        }

        do {
            // Download PDF data
            let (data, response) = try await URLSession.shared.data(from: pdfURL)

            guard let httpResponse = response as? HTTPURLResponse,
                  200...299 ~= httpResponse.statusCode else {
                throw URLError(.badServerResponse)
            }

            // Create a safe filename
            let safeFileName = book.title.replacingOccurrences(of: "[^a-zA-Z0-9 ]", with: "", options: .regularExpression)
            let fileName = "\(safeFileName).pdf"

            // Save to temporary directory first
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try data.write(to: tempURL)

            #if DEBUG
            print("📥 BookReadingView: PDF downloaded to temp directory")
            #endif

            // Present the document picker to let user choose save location
            await MainActor.run {
                // Use UIDocumentPickerViewController to save to Files app
                let documentPicker = UIDocumentPickerViewController(forExporting: [tempURL], asCopy: true)

                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = windowScene.windows.first?.rootViewController {

                    // Find the topmost view controller
                    var topController = rootViewController
                    while let presented = topController.presentedViewController {
                        topController = presented
                    }

                    topController.present(documentPicker, animated: true)
                }

                isDownloadingPDF = false
            }

        } catch {
            await MainActor.run {
                isDownloadingPDF = false
                toastMessage = "Failed to download PDF"
                toastType = .error
                showingToast = true
            }

            #if DEBUG
            print("❌ BookReadingView: PDF download error - \(error)")
            #endif
        }
    }

    // MARK: - Share PDF
    private func sharePDF() async {
        guard !isSharingPDF else { return }
        guard let pdfUrlString = book.pdfUrl,
              let pdfURL = URL(string: pdfUrlString) else {
            await MainActor.run {
                toastMessage = "Invalid PDF URL"
                toastType = .error
                showingToast = true
            }
            return
        }

        await MainActor.run {
            isSharingPDF = true
        }

        do {
            // Download PDF data
            let (data, response) = try await URLSession.shared.data(from: pdfURL)

            guard let httpResponse = response as? HTTPURLResponse,
                  200...299 ~= httpResponse.statusCode else {
                throw URLError(.badServerResponse)
            }

            // Create a safe filename
            let safeFileName = book.title.replacingOccurrences(of: "[^a-zA-Z0-9 ]", with: "", options: .regularExpression)
            let fileName = "\(safeFileName).pdf"

            // Save to temporary directory
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try data.write(to: tempURL)

            #if DEBUG
            print("📤 BookReadingView: PDF prepared for sharing at \(tempURL.path)")
            #endif

            await MainActor.run {
                shareItems = [tempURL]
                showingShareSheet = true
                isSharingPDF = false
            }

        } catch {
            await MainActor.run {
                isSharingPDF = false
                toastMessage = "Failed to prepare PDF for sharing"
                toastType = .error
                showingToast = true
            }

            #if DEBUG
            print("❌ BookReadingView: PDF share error - \(error)")
            #endif
        }
    }

    // MARK: - Delete Book
    private func deleteBook() async {
        guard !isDeleting else { return }

        isDeleting = true

        do {
            try await booksService.deleteBook(bookId: book.id)

            await MainActor.run {
                isDeleting = false
                // Dismiss the view after successful deletion
                dismiss()
            }
        } catch {
            await MainActor.run {
                isDeleting = false
                self.error = error.localizedDescription
                showingError = true
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
    @State private var textHeight: CGFloat = 0.0
    @State private var retryCount = 0
    @State private var isRetrying = false
    
    var body: some View {
        GeometryReader { outerGeometry in
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                if let text = page.text, !text.isEmpty {
                    ScrollView {
                        Text(text)
                            .font(AppTypography.captionLarge)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, AppSpacing.md)
                            .background(
                                GeometryReader { proxy in
                                    Color.clear
                                        .preference(key: TextHeightPreferenceKey.self, value: proxy.size.height)
                                }
                            )
                    }
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: min(max(textHeight, 1), outerGeometry.size.height * 0.45),
                        alignment: .leading
                    )
                    .onPreferenceChange(TextHeightPreferenceKey.self) { height in
                        textHeight = height
                    }
                }

                // Image container with explicit width calculation
                let availableWidth = outerGeometry.size.width - (AppSpacing.lg * 2)

                // Use cache-optimized AsyncImage with retry mechanism
                AsyncImage(url: URL(string: "\(page.imageUrl)?retry=\(retryCount)")) { imagePhase in
                    switch imagePhase {
                    case .success(let image):
                        image
                            .resizable()
                            .interpolation(.high)
                            .antialiased(true)
                            .aspectRatio(contentMode: .fit)
                            .frame(minWidth: availableWidth, maxWidth: availableWidth)
                            .drawingGroup() // Optimize rendering for better performance
                            .scaleEffect(imageScale)
                            .offset(imageOffset)
                            // Zoom gesture (pinch to zoom)
                            .gesture(
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
                                    }
                            )
                            // Pan gesture (only when zoomed) - uses simultaneousGesture to not interfere with TabView swipe
                            .simultaneousGesture(
                                imageScale > 1.2 ? DragGesture()
                                    .onChanged { value in
                                        imageOffset = value.translation
                                    }
                                    .onEnded { _ in
                                        withAnimation(.spring()) {
                                            // Constrain offset to keep image in bounds
                                            let maxOffset = CGSize(
                                                width: availableWidth * (imageScale - 1) / 2,
                                                height: availableWidth * (imageScale - 1) / 2
                                            )

                                            imageOffset.width = max(-maxOffset.width, min(maxOffset.width, imageOffset.width))
                                            imageOffset.height = max(-maxOffset.height, min(maxOffset.height, imageOffset.height))
                                        }
                                    } : nil
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

                    case .failure(let error):
                        VStack(spacing: AppSpacing.md) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 48))
                                .foregroundColor(AppColors.warningOrange)

                            Text("Failed to load page")
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(.white)

                            if retryCount < 3 {
                                Button(action: {
                                    retryLoadImage()
                                }) {
                                    HStack(spacing: AppSpacing.sm) {
                                        if isRetrying {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                                .tint(.white)
                                        } else {
                                            Image(systemName: "arrow.clockwise")
                                                .font(.system(size: 14))
                                        }
                                        Text(isRetrying ? "Retrying..." : "Retry")
                                            .font(AppTypography.bodyMedium)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, AppSpacing.lg)
                                    .padding(.vertical, AppSpacing.sm)
                                    .background(AppColors.primaryBlue, in: Capsule())
                                }
                                .disabled(isRetrying)
                                .childSafeTouchTarget()
                            } else {
                                Text("Please try reloading the book")
                                    .font(AppTypography.captionLarge)
                                    .foregroundColor(.gray)
                            }

                            #if DEBUG
                            Text("Error: \(error.localizedDescription)")
                                .font(AppTypography.captionLarge)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, AppSpacing.md)
                            #endif
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    case .empty:
                        VStack(spacing: AppSpacing.md) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.white)

                            Text("Loading image...")
                                .font(AppTypography.captionLarge)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    @unknown default:
                        EmptyView()
                    }
                }
                .padding(.bottom, AppSpacing.md)
            }
            .padding(.horizontal, AppSpacing.lg)
            .frame(width: outerGeometry.size.width, height: outerGeometry.size.height, alignment: .top)
            .background(Color.black)
        }
    }

    // MARK: - Retry Logic
    private func retryLoadImage() {
        guard retryCount < 3 else { return }

        isRetrying = true

        #if DEBUG
        print("📷 BookPageView: Retrying image load (attempt \(retryCount + 1)/3)")
        #endif

        // Delay to give network time to recover
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay

            await MainActor.run {
                retryCount += 1
                isRetrying = false

                #if DEBUG
                print("📷 BookPageView: Retry triggered - new retry count: \(retryCount)")
                #endif
            }
        }
    }
}

private struct TextHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
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
