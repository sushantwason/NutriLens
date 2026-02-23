import SwiftUI

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var feedbackType: FeedbackType = .general
    @State private var message: String = ""
    @State private var rating: Int = 0
    @State private var submitted = false

    enum FeedbackType: String, CaseIterable, Identifiable {
        case general = "General Feedback"
        case bug = "Bug Report"
        case feature = "Feature Request"
        case accuracy = "Analysis Accuracy"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .general: return "bubble.left.fill"
            case .bug: return "ladybug.fill"
            case .feature: return "lightbulb.fill"
            case .accuracy: return "target"
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
    }

    // MARK: - Form

    private var formView: some View {
        Form {
            Section("How are you enjoying MealSight?") {
                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                rating = star
                            }
                        } label: {
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.title2)
                                .foregroundStyle(star <= rating ? Color.nutriOrange : Color.gray.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section("Feedback Type") {
                Picker("Type", selection: $feedbackType) {
                    ForEach(FeedbackType.allCases) { type in
                        Label(type.rawValue, systemImage: type.icon)
                            .tag(type)
                    }
                }
                .pickerStyle(.navigationLink)
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
        HapticService.notification(.success)
        withAnimation {
            submitted = true
        }
    }
}

#Preview {
    NavigationStack {
        FeedbackView()
    }
}
