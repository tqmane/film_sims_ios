import Foundation
#if canImport(TipKit)
import SwiftUI
import TipKit
#endif

enum FilmSimsTips {
    static var isSupported: Bool {
        #if canImport(TipKit)
        if #available(iOS 17.0, *) {
            return true
        }
        #endif
        return false
    }

    static func configure() {
        #if canImport(TipKit)
        guard #available(iOS 17.0, *) else { return }

        do {
            try Tips.configure()
        } catch {
            print("FilmSimsTips: Failed to configure TipKit: \(error)")
        }
        #endif
    }
}

#if canImport(TipKit)
@available(iOS 17.0, *)
extension FilmSimsTips {
    struct ImportPhotoTip: Tip {
        var title: Text {
            Text(L10n.tr("tip_import_title"))
        }

        var message: Text? {
            Text(L10n.tr("tip_import_message"))
        }

        var image: Image? {
            Image(systemName: "photo.on.rectangle")
        }

        var options: [any Option] {
            [MaxDisplayCount(1)]
        }
    }

    struct ChooseLookTip: Tip {
        var title: Text {
            Text(L10n.tr("tip_choose_look_title"))
        }

        var message: Text? {
            Text(L10n.tr("tip_choose_look_message"))
        }

        var image: Image? {
            Image(systemName: "square.grid.2x2")
        }

        var options: [any Option] {
            [MaxDisplayCount(1)]
        }
    }

    struct RefineSaveTip: Tip {
        var title: Text {
            Text(L10n.tr("tip_refine_save_title"))
        }

        var message: Text? {
            Text(L10n.tr("tip_refine_save_message"))
        }

        var image: Image? {
            Image(systemName: "slider.horizontal.3")
        }

        var options: [any Option] {
            [MaxDisplayCount(1)]
        }
    }
}
#endif
