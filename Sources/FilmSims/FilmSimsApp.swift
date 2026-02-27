import SwiftUI
import FirebaseCore
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // FirebaseApp.configure() looks in Bundle.main, but with SwiftPM the
        // GoogleService-Info.plist lives in Bundle.module. Load it explicitly.
        if let plistURL = Bundle.module.url(forResource: "GoogleService-Info", withExtension: "plist"),
           let options = FirebaseOptions(contentsOfFile: plistURL.path) {
            FirebaseApp.configure(options: options)
        } else {
            // Fallback: try main bundle (e.g. when running via Xcode)
            FirebaseApp.configure()
        }
        return true
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
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
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
