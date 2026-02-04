import SwiftUI

struct BrandSelector: View {
    let brands: [LutBrand]
    @Binding var selectedBrand: LutBrand?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(brands) { brand in
                    ChipButton(
                        title: brand.displayName,
                        isSelected: selectedBrand == brand
                    ) {
                        selectedBrand = brand
                    }
                }
            }
        }
    }
}

struct GenreSelector: View {
    let categories: [LutCategory]
    @Binding var selectedCategory: LutCategory?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(categories) { category in
                    ChipButton(
                        title: category.displayName,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
        }
    }
}

struct ChipButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .tracking(0.12) // Android: letterSpacing=0.01em @ 12sp
                .foregroundColor(isSelected ? .chipSelectedText : Color.white.opacity(0.867)) // #DDFFFFFF
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.chipSelectedBackground : Color.white.opacity(0.188)) // #30FFFFFF
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    isSelected ? Color.accentDark : Color.white.opacity(0.094), // #18FFFFFF
                                    lineWidth: 1.5
                                )
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
