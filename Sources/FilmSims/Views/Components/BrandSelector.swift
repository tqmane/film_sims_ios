import SwiftUI

struct BrandSelector: View {
    let brands: [LutBrand]
    @Binding var selectedBrand: LutBrand?
    var isProUser: Bool = true
    var freeBrands: Set<String> = []
    @Environment(\.layoutMetrics) private var metrics

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: metrics.chipSpacing) {
                ForEach(brands) { brand in
                    let isFree = freeBrands.isEmpty || freeBrands.contains(brand.name) || isProUser
                    ChipButton(
                        title: isFree ? brand.displayName : "\(brand.displayName) 🔒",
                        isSelected: selectedBrand == brand,
                        enabled: isFree
                    ) {
                        if isFree {
                            selectedBrand = brand
                        }
                    }
                }
            }
            .padding(.bottom, metrics.chipRowPadBottom)
        }
    }
}

struct GenreSelector: View {
    let categories: [LutCategory]
    @Binding var selectedCategory: LutCategory?
    @Environment(\.layoutMetrics) private var metrics

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: metrics.chipSpacing) {
                ForEach(categories) { category in
                    ChipButton(
                        title: category.displayName,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.bottom, metrics.chipRowPadBottom)
        }
    }
}

struct ChipButton: View {
    let title: String
    let isSelected: Bool
    var enabled: Bool = true
    let action: () -> Void
    @Environment(\.layoutMetrics) private var metrics

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: metrics.chipFontSize, weight: isSelected ? .medium : .regular))
                .tracking(0.01)
                .foregroundColor(isSelected ? Color.chipSelectedText : Color.textSecondary)
                .padding(.horizontal, metrics.chipHPad)
                .frame(height: metrics.chipHeight)
                .background(
                    RoundedRectangle(cornerRadius: metrics.chipCorner, style: .continuous)
                        .fill(isSelected ? Color.chipSelectedBackground : Color(white: 1, opacity: 0.11))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: metrics.chipCorner, style: .continuous)
                        .stroke(
                            isSelected ? Color.accentPrimary.opacity(0.5) : Color(white: 1, opacity: 0.0627),
                            lineWidth: 1
                        )
                )
                .animation(.easeInOut(duration: 0.3), value: isSelected)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
    }
}
