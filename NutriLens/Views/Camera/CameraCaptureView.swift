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
    @State private var showScanLimitAlert = false

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
            .sheet(isPresented: $showAnalysis) {
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
            .alert("Scan Limit Reached", isPresented: $showScanLimitAlert) {
                Button("Upgrade") {
                    showPaywall = true
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You've used all 100 scans this month. Upgrade to Unlimited for unrestricted scanning.")
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

            VStack {
                // Mode picker
                modePicker
                    .padding(.top, 8)

                // Status badge (trial, standard scan count, or expired)
                if !OwnerBypass.isOwnerDevice && subscriptionManager.currentTier != .unlimited {
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

            Spacer()

            Text("Point camera at a barcode")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 30)
        }
    }

    // MARK: - Capture Controls

    private var captureControls: some View {
        HStack(spacing: 40) {
            // Photo library picker
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Image(systemName: "photo.on.rectangle")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(.ultraThinMaterial, in: Circle())
            }

            // Capture button
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

            // Spacer for symmetry
            Color.clear
                .frame(width: 50, height: 50)
        }
        .padding(.bottom, 30)
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
            } else if subscriptionManager.currentTier == .standard {
                Image(systemName: "camera.fill")
                    .font(.caption2)
                let remaining = scanCounter.remainingScans
                Text("\(scanCounter.monthlyCount) / \(ScanCounter.standardMonthlyLimit) scans")
                    .font(.caption.weight(.medium))
                if remaining <= 10 && remaining > 0 {
                    Text("\(remaining) left")
                        .font(.caption2.weight(.bold))
                }
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
        case .unlimited:
            await analyzeImage(image)
        case .standard:
            if scanCounter.canScan(tier: .standard) {
                scanCounter.recordScan()
                await analyzeImage(image)
            } else {
                // Scan limit reached
                showScanLimitAlert = true
            }
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

    // MARK: - Barcode Scanning

    private func startBarcodeScan() {
        guard !isBarcodeScanning else { return }

        // Trial users: free access
        if trialManager.isTrialActive || OwnerBypass.isOwnerDevice {
            performBarcodeScan(shouldRecordScan: false)
            return
        }

        switch subscriptionManager.currentTier {
        case .unlimited:
            performBarcodeScan(shouldRecordScan: false)
        case .standard:
            if scanCounter.canScan(tier: .standard) {
                // Record scan only after barcode is successfully found
                performBarcodeScan(shouldRecordScan: true)
            } else {
                showScanLimitAlert = true
            }
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
