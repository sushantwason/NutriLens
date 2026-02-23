import SwiftUI
import PhotosUI

enum ScanMode: String, CaseIterable {
    case meal = "Meal Photo"
    case label = "Nutrition Label"
    case barcode = "Barcode"
    case recipe = "Recipe"

    var icon: String {
        switch self {
        case .meal: return "fork.knife"
        case .label: return "doc.text"
        case .barcode: return "barcode.viewfinder"
        case .recipe: return "book"
        }
    }
}

struct CameraCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(TrialManager.self) private var trialManager
    @Environment(ScanCounter.self) private var scanCounter

    @State private var cameraService = CameraService()
    @State private var scanMode: ScanMode = .meal
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var capturedImage: UIImage?
    @State private var showAnalysis = false
    @State private var showPaywall = false

    @State private var mealAnalysisVM = MealAnalysisViewModel()
    @State private var labelScanVM = LabelScanViewModel()
    @State private var barcodeVM = BarcodeViewModel()
    @State private var recipeAnalysisVM = RecipeAnalysisViewModel()

    @State private var isBarcodeScanning = false
    @State private var capturedImages: [UIImage] = []  // Multi-photo capture for meal mode

    var body: some View {
        NavigationStack {
            ZStack {
                if cameraService.isAuthorized {
                    cameraPreview
                } else {
                    cameraPermissionView
                }
            }
            .navigationTitle("Scan Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showAnalysis, onDismiss: {
                // Free multi-photo memory when analysis sheet closes
                capturedImages.removeAll()
            }) {
                switch scanMode {
                case .meal:
                    MealAnalysisResultView(viewModel: mealAnalysisVM)
                case .label:
                    LabelScanResultView(viewModel: labelScanVM)
                case .barcode:
                    BarcodeResultView(viewModel: barcodeVM)
                case .recipe:
                    RecipeAnalysisResultView(viewModel: recipeAnalysisVM)
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .task {
                await cameraService.checkAuthorization()
                if cameraService.isAuthorized {
                    cameraService.setupSession()
                    cameraService.startSession()
                }
            }
            .onDisappear {
                cameraService.stopBarcodeScanning()
                cameraService.stopSession()
            }
        }
    }

    // MARK: - Camera Preview

    private var cameraPreview: some View {
        ZStack {
            CameraPreviewRepresentable(session: cameraService.session)
                .ignoresSafeArea()
                .accessibilityLabel("Camera preview")
                .accessibilityAddTraits(.isImage)

            // Show captured/selected image full-screen while analyzing
            if let image = capturedImage, mealAnalysisVM.analysisState == .analyzing || labelScanVM.analysisState == .analyzing || recipeAnalysisVM.analysisState == .analyzing {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .overlay {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                    }
                    .overlay {
                        VStack(spacing: 16) {
                            ProgressView()
                                .controlSize(.large)
                                .tint(.white)
                            Text("Analyzing...")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                    }
                    .transition(.opacity)
            }

            VStack {
                // Mode picker
                modePicker
                    .padding(.top, 8)

                // Status badge (trial or expired)
                if !OwnerBypass.isOwnerDevice && !subscriptionManager.isProUser {
                    trialBadge
                        .padding(.top, 4)
                }

                Spacer()

                if scanMode == .barcode {
                    barcodeOverlay
                } else {
                    captureControls
                }
            }
        }
        .onChange(of: selectedPhoto) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    capturedImage = image
                    await attemptScan(with: image)
                }
            }
        }
        .onChange(of: scanMode) { oldValue, newValue in
            if oldValue == .barcode {
                cameraService.stopBarcodeScanning()
                isBarcodeScanning = false
            }
            if oldValue == .meal {
                capturedImages.removeAll()
            }
            if newValue == .barcode {
                startBarcodeScan()
            }
        }
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        Menu {
            ForEach(ScanMode.allCases, id: \.self) { mode in
                Button {
                    scanMode = mode
                } label: {
                    Label(mode.rawValue, systemImage: mode.icon)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: scanMode.icon)
                    .font(.subheadline)
                Text(scanMode.rawValue)
                    .font(.subheadline.weight(.medium))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .accessibilityLabel("Scan mode: \(scanMode.rawValue)")
        .accessibilityHint("Double tap to change scan mode")
    }

    // MARK: - Barcode Overlay

    private var barcodeOverlay: some View {
        VStack(spacing: 16) {
            Spacer()

            // Viewfinder frame
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white, lineWidth: 2)
                .frame(width: 280, height: 140)
                .overlay {
                    if isBarcodeScanning {
                        Text("Scanning...")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }
                .accessibilityHidden(true)

            Spacer()

            Text("Point camera at a barcode")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 30)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isBarcodeScanning ? "Scanning for barcode" : "Point camera at a barcode")
        .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: - Capture Controls

    private var captureControls: some View {
        VStack(spacing: 12) {
            // Multi-photo thumbnail strip (meal mode only)
            if scanMode == .meal && !capturedImages.isEmpty {
                capturedPhotosStrip
            }

            HStack(spacing: 40) {
                // Photo library picker
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Choose photo from library")
                .accessibilityHint("Opens photo library to select an image for analysis")

                // Capture button — auto-analyzes immediately for all modes
                Button {
                    Task {
                        if let image = await cameraService.capturePhoto() {
                            capturedImage = image
                            await attemptScan(with: image)
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 72, height: 72)
                        Circle()
                            .stroke(.white, lineWidth: 4)
                            .frame(width: 80, height: 80)
                    }
                }
                .accessibilityLabel("Take photo")
                .accessibilityHint("Captures a photo of your \(scanMode.rawValue.lowercased())")

                // Analyze All button (meal mode with photos) or spacer
                if scanMode == .meal && !capturedImages.isEmpty {
                    Button {
                        Task { await analyzeAllMealPhotos() }
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "sparkles")
                                .font(.title3)
                            Text("Analyze")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(.green.gradient, in: Circle())
                    }
                    .accessibilityLabel("Analyze \(capturedImages.count) \(capturedImages.count == 1 ? "photo" : "photos")")
                    .accessibilityHint("Sends captured photos for nutritional analysis")
                } else {
                    Color.clear
                        .frame(width: 50, height: 50)
                }
            }
            .padding(.bottom, 30)
        }
    }

    // MARK: - Captured Photos Strip

    private var capturedPhotosStrip: some View {
        VStack(spacing: 6) {
            Text("\(capturedImages.count) photo\(capturedImages.count == 1 ? "" : "s") captured")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(capturedImages.enumerated()), id: \.offset) { index, image in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(.white.opacity(0.5), lineWidth: 1)
                                )
                                .accessibilityLabel("Captured photo \(index + 1)")

                            // Remove button
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    let idx: Int = index
                                    capturedImages.remove(at: idx)
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .red)
                            }
                            .offset(x: 4, y: -4)
                            .accessibilityLabel("Remove photo \(index + 1)")
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    // MARK: - Status Badge

    private var trialBadge: some View {
        HStack(spacing: 6) {
            if trialManager.isTrialActive {
                Image(systemName: "clock.fill")
                    .font(.caption2)
                let days = trialManager.trialDaysRemaining
                Text("\(days) day\(days == 1 ? "" : "s") left in trial")
                    .font(.caption.weight(.medium))
            } else {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                Text("Trial expired")
                    .font(.caption.weight(.medium))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .accessibilityElement(children: .combine)
    }

    // MARK: - Permission View

    private var cameraPermissionView: some View {
        ContentUnavailableView {
            Label("Camera Access Required", systemImage: "camera.fill")
        } description: {
            Text("MealSight needs camera access to photograph your meals. You can also select photos from your library.")
        } actions: {
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Text("Choose from Library")
            }
            .buttonStyle(.borderedProminent)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .accessibilityHint("Opens device settings to grant camera permission")
        }
    }

    // MARK: - Scan Gating

    private func attemptScan(with image: UIImage) async {
        // Trial users: free access
        if trialManager.isTrialActive {
            await analyzeImage(image)
            return
        }

        // Owner bypass: unlimited
        if OwnerBypass.isOwnerDevice {
            await analyzeImage(image)
            return
        }

        switch subscriptionManager.currentTier {
        case .pro:
            scanCounter.recordScan()
            await analyzeImage(image)
        case .none:
            if subscriptionManager.products.isEmpty {
                await subscriptionManager.loadProducts()
            }
            showPaywall = true
        }
    }

    // MARK: - Analysis

    private func analyzeImage(_ image: UIImage) async {
        switch scanMode {
        case .meal:
            mealAnalysisVM.reset()
            showAnalysis = true
            await mealAnalysisVM.analyzePhoto(image)
        case .label:
            labelScanVM.reset()
            showAnalysis = true
            await labelScanVM.analyzeLabel(image)
        case .barcode:
            // Barcode uses live scanning, not image capture
            break
        case .recipe:
            recipeAnalysisVM.reset()
            showAnalysis = true
            await recipeAnalysisVM.analyzeRecipe(image)
        }
    }

    private func analyzeAllMealPhotos() async {
        guard !capturedImages.isEmpty else { return }
        await attemptMealScan(with: capturedImages)
    }

    /// Scan-gating for multi-image meal analysis (mirrors attemptScan but for [UIImage])
    private func attemptMealScan(with images: [UIImage]) async {
        if trialManager.isTrialActive {
            await analyzeMealImages(images)
            return
        }

        if OwnerBypass.isOwnerDevice {
            await analyzeMealImages(images)
            return
        }

        switch subscriptionManager.currentTier {
        case .pro:
            scanCounter.recordScan()
            await analyzeMealImages(images)
        case .none:
            if subscriptionManager.products.isEmpty {
                await subscriptionManager.loadProducts()
            }
            showPaywall = true
        }
    }

    private func analyzeMealImages(_ images: [UIImage]) async {
        mealAnalysisVM.reset()
        showAnalysis = true
        await mealAnalysisVM.analyzePhotos(images)
    }

    // MARK: - Barcode Scanning

    private func startBarcodeScan() {
        guard !isBarcodeScanning else { return }

        // Trial users: free access
        if trialManager.isTrialActive || OwnerBypass.isOwnerDevice {
            performBarcodeScan(shouldRecordScan: false)
            return
        }

        switch subscriptionManager.currentTier {
        case .pro:
            performBarcodeScan(shouldRecordScan: true)
        case .none:
            Task {
                if subscriptionManager.products.isEmpty {
                    await subscriptionManager.loadProducts()
                }
            }
            showPaywall = true
        }
    }

    private func performBarcodeScan(shouldRecordScan: Bool) {
        isBarcodeScanning = true
        Task {
            if let barcode = await cameraService.startBarcodeScanning() {
                // Only record the scan after successfully detecting a barcode
                if shouldRecordScan {
                    scanCounter.recordScan()
                }
                isBarcodeScanning = false
                barcodeVM.reset()
                showAnalysis = true
                await barcodeVM.lookupBarcode(barcode)
            } else {
                isBarcodeScanning = false
            }
        }
    }
}

#Preview {
    CameraCaptureView()
        .environment(SubscriptionManager())
        .environment(TrialManager())
        .environment(ScanCounter())
        .environment(HealthKitManager())
}
