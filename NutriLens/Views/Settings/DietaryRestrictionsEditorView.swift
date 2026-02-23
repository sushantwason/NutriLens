import SwiftUI
import SwiftData

struct DietaryRestrictionsEditorView: View {
    @Bindable var profile: UserProfile

    var body: some View {
        List {
            Section {
                Text("Select any dietary restrictions. These are used for dietary alerts when scanning meals and for AI Coach meal suggestions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                let restrictions = profile.dietaryRestrictions
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(DietaryRestriction.allCases) { restriction in
                        let isSelected = restrictions.contains(restriction)
                        Button {
                            var updated = restrictions
                            if isSelected {
                                updated.removeAll { $0 == restriction }
                            } else {
                                updated.append(restriction)
                            }
                            profile.dietaryRestrictions = updated
                            profile.updatedDate = Date()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: restriction.icon)
                                    .font(.caption2)
                                Text(restriction.displayName)
                                    .font(.caption.weight(.medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                isSelected ? Color.nutriGreen.opacity(0.15) : Color(.systemGray6),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isSelected ? Color.nutriGreen : .clear, lineWidth: 1.5)
                            )
                            .foregroundStyle(isSelected ? .nutriGreen : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Dietary Restrictions")
        .navigationBarTitleDisplayMode(.inline)
    }
}
