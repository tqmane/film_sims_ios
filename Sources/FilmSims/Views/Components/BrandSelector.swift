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
                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                .tracking(0.01)
                .foregroundColor(isSelected ? Color.chipSelectedText : Color.chipUnselectedText)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isSelected ? Color.chipSelectedBackground : Color.chipUnselectedBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            isSelected ? Color.accentDark : Color.glassBorderAndroid,
                            lineWidth: 1.5
                        )
                )
                .animation(.easeInOut(duration: 0.3), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}
