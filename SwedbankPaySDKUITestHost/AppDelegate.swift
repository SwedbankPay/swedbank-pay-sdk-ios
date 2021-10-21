import UIKit
import SwedbankPaySDK

let shouldRestoreState = CommandLine.arguments.contains("-restore")

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
        
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        SwedbankPaySDKController.defaultConfiguration = paymentTestConfiguration
        return true
    }
    
    func application(_ application: UIApplication, shouldSaveSecureApplicationState coder: NSCoder) -> Bool {
        application.ignoreSnapshotOnNextApplicationLaunch()
        return true
    }
    
    func application(_ application: UIApplication, shouldRestoreSecureApplicationState coder: NSCoder) -> Bool {
        return shouldRestoreState
    }
}
