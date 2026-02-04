import Foundation
import UIKit

@MainActor
class LutRepository {
    static let shared = LutRepository()
    
    private let lutExtensions = [".cube", ".png", ".bin"]
    
    private init() {}
    
    // MARK: - Category Display Names
    private func getCategoryDisplayName(_ categoryName: String) -> String {
        switch categoryName {
        // OnePlus categories
        case "App Filters": return L10n.tr("category_app_filters")
        case "Artistic": return L10n.tr("category_artistic")
        case "Black & White": return L10n.tr("category_black_white")
        case "Cinematic Movie": return L10n.tr("category_cinematic_movie")
        case "Cool Tones": return L10n.tr("category_cool_tones")
        case "Food": return L10n.tr("category_food")
        case "Golden Touch": return L10n.tr("category_golden_touch")
        case "Instagram Filters": return L10n.tr("category_instagram_filters")
        case "Japanese Style": return L10n.tr("category_japanese_style")
        case "Landscape": return L10n.tr("category_landscape")
        case "Night": return L10n.tr("category_night")
        case "Portrait": return L10n.tr("category_portrait")
        case "Uncategorized": return L10n.tr("category_uncategorized")
        case "Vintage-Retro": return L10n.tr("category_vintage_retro")
        case "Warm Tones": return L10n.tr("category_warm_tones")
        // Xiaomi categories
        case "Cinematic": return L10n.tr("category_cinematic")
        case "Film Simulation": return L10n.tr("category_film_simulation")
        case "Monochrome": return L10n.tr("category_monochrome")
        case "Nature-Landscape": return L10n.tr("category_nature_landscape")
        case "Portrait-Soft": return L10n.tr("category_portrait_soft")
        case "Special Effects": return L10n.tr("category_special_effects")
        case "Vivid-Natural": return L10n.tr("category_vivid_natural")
        case "Warm-Vintage": return L10n.tr("category_warm_vintage")
        // Leica_lux categories
        case "Leica Looks": return L10n.tr("category_leica_looks")
        case "Artist Looks": return L10n.tr("category_artist_looks")
        // Common/Nothing
        case "_all": return L10n.tr("category_all")
        default:
            return categoryName.replacingOccurrences(of: "_", with: " ")
                              .replacingOccurrences(of: "-", with: " - ")
        }
    }
    
    // MARK: - Brand Display Names
    private func getBrandDisplayName(_ brandName: String) -> String {
        switch brandName {
        case "Leica_lux": return L10n.tr("brand_leica_lux")
        default: return brandName
        }
    }
    
    // MARK: - Leica Filter Names
    private func getLeicaLuxFilterName(_ fileName: String) -> String {
        // Exact mappings based on Sources/FilmSims/Resources/luts/Leica_lux/leica_lux_filter.md
        let mapping: [String: String] = [
            "Classic_sRGB_sRGB_Release_opacity_65": "lut_leica_classic",
            "Contemporary_sRGB_sRGB_Release_opacity_65": "lut_leica_contemporary",
            "Leica-Filter_Monochrome_DP3_DP3_Release": "lut_leica_monochrome_natural",
            "Leica-Filter_Natural_DP3_DP3_Release": "lut_leica_natural",
            "Leica-Looks_Blue_sRGB_sRGB_Release": "lut_leica_blue",
            "Leica-Looks_Eternal_sRGB_sRGB_Release": "lut_leica_eternal",
            "Leica-Looks_Selenium_sRGB_sRGB_Release": "lut_leica_selenium",
            "Leica-Looks_Sepia_sRGB_sRGB_Release": "lut_leica_sepia",
            "Leica-Looks_Silver_sRGB_sRGB_Release": "lut_leica_silver",
            "Leica-Looks_Teal_sRGB_sRGB_Release": "lut_leica_teal",
            "Leica_Bleach_sRGB_sRGB_Release": "lut_leica_bleach",
            "Leica_Brass_sRGB_sRGB_Release": "lut_leica_brass",
            "Leica_Monochrome_High_Contrast_sRGB_sRGB_Release": "lut_leica_high_contrast",
            "Leica_Vivid_sRGB_sRGB_Release": "lut_leica_vivid",
            "Tyson_100yearsMono1A_sRGB_sRGB_Release": "lut_100_years_mono",
            "Tyson_GregWilliams_Sepia0_DP3_DP3_Release": "lut_greg_williams_sepia_0",
            "Tyson_GregWilliams_Sepia100_DP3_DP3_Release": "lut_greg_williams_sepia_100",
            "Tyson_Leica_Base_V3_DP3_DP3_Release": "lut_leica_standard",
            "Tyson_Leica_Chrome_sRGB_sRGB_Release": "lut_leica_chrome",
        ]

        if let key = mapping[fileName] {
            return L10n.tr(key)
        }

        // Backward-compatible fuzzy matching (in case file names change slightly).
        if fileName.contains("Classic_sRGB") { return L10n.tr("lut_leica_classic") }
        if fileName.contains("Contemporary_sRGB") { return L10n.tr("lut_leica_contemporary") }
        if fileName.contains("Leica-Filter_Monochrome") { return L10n.tr("lut_leica_monochrome_natural") }
        if fileName.contains("Leica-Filter_Natural") { return L10n.tr("lut_leica_natural") }
        if fileName.contains("Leica-Looks_Blue") { return L10n.tr("lut_leica_blue") }
        if fileName.contains("Leica-Looks_Eternal") { return L10n.tr("lut_leica_eternal") }
        if fileName.contains("Leica-Looks_Selenium") { return L10n.tr("lut_leica_selenium") }
        if fileName.contains("Leica-Looks_Sepia") { return L10n.tr("lut_leica_sepia") }
        if fileName.contains("Leica-Looks_Silver") { return L10n.tr("lut_leica_silver") }
        if fileName.contains("Leica-Looks_Teal") { return L10n.tr("lut_leica_teal") }
        if fileName.contains("Leica_Bleach") { return L10n.tr("lut_leica_bleach") }
        if fileName.contains("Leica_Brass") { return L10n.tr("lut_leica_brass") }
        if fileName.contains("Leica_Monochrome_High_Contrast") { return L10n.tr("lut_leica_high_contrast") }
        if fileName.contains("Leica_Vivid") { return L10n.tr("lut_leica_vivid") }
        if fileName.contains("Tyson_100yearsMono") { return L10n.tr("lut_100_years_mono") }
        if fileName.contains("Tyson_GregWilliams_Sepia0") { return L10n.tr("lut_greg_williams_sepia_0") }
        if fileName.contains("Tyson_GregWilliams_Sepia100") { return L10n.tr("lut_greg_williams_sepia_100") }
        if fileName.contains("Tyson_Leica_Base_V3") { return L10n.tr("lut_leica_standard") }
        if fileName.contains("Tyson_Leica_Chrome") { return L10n.tr("lut_leica_chrome") }
        return fileName.replacingOccurrences(of: "_", with: " ")
    }
    
    // MARK: - Load LUT Brands
    func getLutBrands() -> [LutBrand] {
        var brands: [LutBrand] = []

        // SwiftPM resources are packaged into a separate bundle (Bundle.module),
        // not necessarily into the main app bundle.
        let resourceBundle = Bundle.module
        guard let resourcePath = resourceBundle.resourcePath else { return [] }
        let lutsPath = (resourcePath as NSString).appendingPathComponent("luts")
        
        let fileManager = FileManager.default
        
        guard let brandFolders = try? fileManager.contentsOfDirectory(atPath: lutsPath) else {
            return []
        }
        
        for brandName in brandFolders.sorted() {
            let brandPath = (lutsPath as NSString).appendingPathComponent(brandName)
            
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: brandPath, isDirectory: &isDirectory),
                  isDirectory.boolValue else { continue }
            
            guard let contents = try? fileManager.contentsOfDirectory(atPath: brandPath) else { continue }
            
            var categories: [LutCategory] = []
            let isLeicaLux = brandName == "Leica_lux"
            
            // Check for flat structure (LUT files directly in brand folder)
            let directLutFiles = contents.filter { file in
                lutExtensions.contains { file.lowercased().hasSuffix($0) }
            }
            
            if !directLutFiles.isEmpty {
                // Flat structure - create single "All" category
                let lutItems = createLutItems(from: directLutFiles, basePath: brandPath, isLeicaLux: isLeicaLux)
                
                categories.append(LutCategory(
                    name: "_all",
                    displayName: getCategoryDisplayName("_all"),
                    items: lutItems
                ))
            }
            
            // Check for subdirectories (category folders)
            let categoryFolders = contents.filter { name in
                !lutExtensions.contains { name.lowercased().hasSuffix($0) }
            }
            
            for categoryName in categoryFolders {
                let categoryPath = (brandPath as NSString).appendingPathComponent(categoryName)
                
                var isCategoryDir: ObjCBool = false
                guard fileManager.fileExists(atPath: categoryPath, isDirectory: &isCategoryDir),
                      isCategoryDir.boolValue else { continue }
                
                guard let files = try? fileManager.contentsOfDirectory(atPath: categoryPath) else { continue }
                
                let lutFiles = files.filter { file in
                    lutExtensions.contains { file.lowercased().hasSuffix($0) }
                }
                
                let lutItems = createLutItems(from: lutFiles, basePath: categoryPath, isLeicaLux: isLeicaLux)
                
                if !lutItems.isEmpty {
                    categories.append(LutCategory(
                        name: categoryName,
                        displayName: getCategoryDisplayName(categoryName),
                        items: lutItems
                    ))
                }
            }
            
            if !categories.isEmpty {
                brands.append(LutBrand(
                    name: brandName,
                    displayName: getBrandDisplayName(brandName),
                    categories: categories.sorted { $0.displayName < $1.displayName }
                ))
            }
        }
        
        return brands.sorted { $0.displayName < $1.displayName }
    }
    
    private func createLutItems(from files: [String], basePath: String, isLeicaLux: Bool) -> [LutItem] {
        // Group by basename to handle duplicates
        var groupedFiles: [String: [String]] = [:]
        
        for file in files {
            var baseName = file
            for ext in lutExtensions {
                baseName = baseName.replacingOccurrences(of: ext, with: "", options: .caseInsensitive)
            }
            
            if groupedFiles[baseName] == nil {
                groupedFiles[baseName] = []
            }
            groupedFiles[baseName]?.append(file)
        }
        
        var items: [LutItem] = []
        
        for (baseName, variants) in groupedFiles {
            // Select best file: .bin -> .cube -> .png
            let selectedFile = variants.first { $0.lowercased().hasSuffix(".bin") }
                ?? variants.first { $0.lowercased().hasSuffix(".cube") }
                ?? variants.first!
            
            let displayName = isLeicaLux
                ? getLeicaLuxFilterName(baseName)
                : baseName.replacingOccurrences(of: "_", with: " ")
            
            let assetPath = (basePath as NSString).appendingPathComponent(selectedFile)
            
            items.append(LutItem(
                name: displayName,
                assetPath: assetPath
            ))
        }
        
        return items.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
}
