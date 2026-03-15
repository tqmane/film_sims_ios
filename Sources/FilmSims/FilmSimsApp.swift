import SwiftUI
import FirebaseCore
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        if let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let options = FirebaseOptions(contentsOfFile: plistPath) {
            FirebaseApp.configure(options: options)
        } else if let plistURL = Bundle.module.url(forResource: "GoogleService-Info", withExtension: "plist"),
                  let options = FirebaseOptions(contentsOfFile: plistURL.path) {
            FirebaseApp.configure(options: options)
        } else {
            FirebaseApp.configure()
        }
        AnalyticsManager.configure()
        FilmSimsTips.configure()
        _ = AuthViewModel.shared
        return true
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        NSLog("AppDelegate: application(_:open:) called with url=%@", url.absoluteString)
        if GIDSignIn.sharedInstance.handle(url) {
            NSLog("AppDelegate: GIDSignIn handled URL")
            return true
        }
        return IncomingImageCoordinator.shared.handle(url: url)
    }
}

@main
struct FilmSimsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    NSLog("FilmSimsApp: onOpenURL called with url=%@", url.absoluteString)
                    if GIDSignIn.sharedInstance.handle(url) {
                        NSLog("FilmSimsApp: GIDSignIn handled URL")
                        return
                    }
                    _ = IncomingImageCoordinator.shared.handle(url: url)
                }
        }
    }
}
