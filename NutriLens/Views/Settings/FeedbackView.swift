import SwiftUI
import MessageUI

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: FeedbackCategory = .general
    @State private var message: String = ""
    @State private var submitted = false
    @State private var showMailError = false

    enum FeedbackCategory: String, CaseIterable, Identifiable {
        case general = "General Feedback"
        case bug = "Bug Report"
        case feature = "Feature Request"
        case scanning = "Scanning Issue"
        case design = "Design/UX"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .general: return "bubble.left.fill"
            case .bug: return "ladybug.fill"
            case .feature: return "lightbulb.fill"
            case .scanning: return "camera.fill"
            case .design: return "paintbrush.fill"
            }
        }

        var chipLabel: String {
            switch self {
            case .general: return "General Feedback"
            case .bug: return "Bug Report"
            case .feature: return "Feature Request"
            case .scanning: return "Scanning Issue"
            case .design: return "Design/UX"
            }
        }
    }

    var body: some View {
        Group {
            if submitted {
                thankYouView
            } else {
                formView
            }
        }
        .navigationTitle("Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Unable to Send Email", isPresented: $showMailError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your device isn't configured for email. Please send your feedback to nutrilenshealth@gmail.com")
        }
    }

    // MARK: - Form

    private var formView: some View {
        Form {
            Section("What's this about?") {
                FlowLayout(spacing: 8) {
                    ForEach(FeedbackCategory.allCases) { category in
                        CategoryChip(
                            label: category.chipLabel,
                            icon: category.icon,
                            isSelected: selectedCategory == category
                        ) {
                            withAnimation(.spring(response: 0.25)) {
                                selectedCategory = category
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Your Feedback") {
                TextEditor(text: $message)
                    .frame(minHeight: 120)
                    .overlay(alignment: .topLeading) {
                        if message.isEmpty {
                            Text("Tell us what you think, report a bug, or suggest a feature...")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                    }
            }

            Section {
                Button {
                    submitFeedback()
                } label: {
                    HStack {
                        Spacer()
                        Label("Submit Feedback", systemImage: "paperplane.fill")
                            .font(.body.weight(.semibold))
                        Spacer()
                    }
                }
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    // MARK: - Thank You

    private var thankYouView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "heart.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.nutriGreen)

            Text("Thank You!")
                .font(.title.weight(.bold))

            Text("Your feedback helps us make MealSight better for everyone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 14)
                    .background(.nutriGreen, in: Capsule())
            }
            .padding(.top, 12)

            Spacer()
        }
    }

    // MARK: - Submit

    private func submitFeedback() {
        let subject = "[\(selectedCategory.chipLabel)] MealSight Feedback"
        let body = """
        Category: \(selectedCategory.chipLabel)

        \(message)

        ---
        MealSight v1.0 (6)
        """

        if let emailURL = createEmailURL(to: "nutrilenshealth@gmail.com", subject: subject, body: body) {
            UIApplication.shared.open(emailURL) { success in
                if success {
                    HapticService.notification(.success)
                    withAnimation { submitted = true }
                }
            }
        } else {
            showMailError = true
        }
    }

    private func createEmailURL(to email: String, subject: String, body: String) -> URL? {
        let subjectEncoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let bodyEncoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "mailto:\(email)?subject=\(subjectEncoded)&body=\(bodyEncoded)")
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption2.weight(.semibold))
                Text(label)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.nutriGreen.opacity(0.15) : Color(.systemGray6))
            .foregroundStyle(isSelected ? .nutriGreen : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.nutriGreen : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        FeedbackView()
    }
}
