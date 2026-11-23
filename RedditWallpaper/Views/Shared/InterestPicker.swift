import SwiftUI
import WallpaperCore

/// The grid of interests used in onboarding, Settings and the Library's
/// "Edit Interests" sheet. Changes save immediately.
struct InterestPicker: View {
    @Environment(AppModel.self) var model
    @State var customText = ""
    private let columns = [GridItem(.adaptive(minimum: 158), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(InterestCatalog.presets + model.settings.customInterests) { interest in
                    InterestTile(
                        interest: interest,
                        isSelected: model.settings.isSelected(interest),
                        toggle: { model.settings.toggleInterest(interest) },
                        onRemove: interest.isCustom ? { model.settings.removeCustomInterest(id: interest.id) } : nil)
                }
            }
            HStack(spacing: 8) {
                TextField("Add your own, like “Porsche 911” or “Real Madrid”", text: $customText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addCustom)
                Button("Add", action: addCustom)
                    .disabled(customText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func addCustom() {
        if model.settings.addCustomInterest(named: customText) != nil {
            customText = ""
        }
    }
}

struct InterestTile: View {
    let interest: Interest
    let isSelected: Bool
    let toggle: () -> Void
    var onRemove: (() -> Void)? = nil

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 10) {
                SymbolImage(interest.symbol, fallback: "star.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : interest.tint)
                    .frame(width: 30, height: 30)
                    .background(isSelected ? interest.tint : interest.tint.opacity(0.15), in: Circle())
                Text(interest.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(interest.tint)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? interest.tint.opacity(0.12) : Color.primary.opacity(0.04)))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? interest.tint.opacity(0.6) : Color.clear, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onRemove {
                Button("Remove “\(interest.name)”", role: .destructive, action: onRemove)
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A compact interest filter for the menu bar popover.
struct InterestChip: View {
    let title: String
    let symbol: String
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                SymbolImage(symbol, fallback: "star.fill")
                Text(title)
            }
            .font(.callout.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(Capsule().fill(isSelected ? tint : Color.primary.opacity(0.07)))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
