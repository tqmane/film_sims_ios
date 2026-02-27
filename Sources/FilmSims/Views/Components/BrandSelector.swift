import SwiftUI

struct BrandSelector: View {
    let brands: [LutBrand]
    @Binding var selectedBrand: LutBrand?
    var isProUser: Bool = true
    var freeBrands: Set<String> = []
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
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
            .padding(.bottom, 12)
        }
    }
}

struct GenreSelector: View {
    let categories: [LutCategory]
    @Binding var selectedCategory: LutCategory?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories) { category in
                    ChipButton(
                        title: category.displayName,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.bottom, 12)
        }
    }
}

struct ChipButton: View {
    let title: String
    let isSelected: Bool
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                // Android: 13sp, medium selected / normal unselected
                .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                .tracking(0.01)
                // Android: ChipSelectedText = #0C0C10, TextMediumEmphasis = 0xD8FFFFFF
                .foregroundColor(isSelected ? Color.chipSelectedText : Color.textSecondary)
                // Android: horizontal padding 16dp, height 36dp, corner 20dp
                .padding(.horizontal, 16)
                .frame(height: 36)
                .background(
                    // Android: selected = ChipSelected (#FFAB60), unselected = 0x1CFFFFFF
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(isSelected ? Color.chipSelectedBackground : Color(white: 1, opacity: 0.11))
                )
                .overlay(
                    // Android: border 1dp, selected = AccentPrimary 50%, unselected = 0x10FFFFFF
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
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
