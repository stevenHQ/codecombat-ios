//
//  AppDelegate.swift
//  iPadClient
//
//  Created by Michael Schmatz on 7/26/14.
//  Copyright (c) 2014 CodeCombat. All rights reserved.
//


//
//  AppDelegate.swift
//  GDWebBrowserClient
//
//  Created by Alex G on 03.12.14.
//  Copyright (c) 2015 Alexey Gordiyenko. All rights reserved.
//

//import UIKit
//import WebKit
//
//let gHost = "http://hackathon.reindeerjob.com/play"
//let rootURL = NSURL(string: "http://hackathon.reindeerjob.com")!
//let gShowAlertOnDidFinishLoading = false
//
//@UIApplicationMain
//class AppDelegate: UIResponder, UIApplicationDelegate, GDWebViewControllerDelegate {
//    
//    
//    // MARK: Properties
//    var window: UIWindow?
//    
//    // MARK: Private Properties
//    var webVC = GDWebViewController()
//    var navVC = UINavigationController()
//    
//    // MARK: GDWebViewControllerDelegate Methods
//    
//    func webViewController(webViewController: GDWebViewController, didChangeTitle newTitle: NSString?) {
//        navVC.navigationBar.topItem?.title = newTitle as? String
//    }
//    
//    func webViewController(webViewController: GDWebViewController, decidePolicyForNavigationAction navigationAction: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> Void) {
//        if let URL = NSURL(string: "/play", relativeToURL: rootURL),
//            //if let URL = navigationAction.request.URL as NSURL?,
//            host = URL.host as NSString?
//        {
//            let testSubdomain = "." + gHost
//            if host as String == gHost || host.rangeOfString(testSubdomain, options: .CaseInsensitiveSearch).location != NSNotFound {
//                decisionHandler(.Allow)
//                return
//            }
//        }
//        
//        print(navigationAction.request.URL)
//        decisionHandler(.Allow)
//    }
//    
//    func webViewController(webViewController: GDWebViewController, didFinishLoading loadedURL: NSURL?) {
//        if gShowAlertOnDidFinishLoading {
//            webViewController.evaluateJavaScript("alert('Loaded!')", completionHandler: nil)
//        }
//    }
//    
//    // MARK: Life Cycle
//    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
//        // Override point for customization after application launch.
//        window = UIWindow(frame: UIScreen.mainScreen().bounds)
//        navVC.setViewControllers([webVC], animated: true)
//        window?.rootViewController = navVC
//        window?.makeKeyAndVisible()
//        
//        webVC.delegate = self
//        webVC.navigationController?.navigationBarHidden = true
//        webVC.loadURLWithString(gHost)
//        webVC.toolbar.toolbarTintColor = UIColor.darkGrayColor()
//        webVC.toolbar.toolbarBackgroundColor = UIColor.whiteColor()
//        webVC.toolbar.toolbarTranslucent = false
//        webVC.allowsBackForwardNavigationGestures = true
//        
//        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,Int64(1 * Double(NSEC_PER_SEC))),dispatch_get_main_queue(), {
//            self.webVC.showToolbar(false, animated: true)
//        })
//        
//        return true
//    }
//    
//    func applicationWillResignActive(application: UIApplication) {
//    }
//    
//    func applicationDidEnterBackground(application: UIApplication) {
//    }
//    
//    func applicationWillEnterForeground(application: UIApplication) {
//    }
//    
//    func applicationDidBecomeActive(application: UIApplication) {
//    }
//    
//    func applicationWillTerminate(application: UIApplication) {
//    }
//    
//}



import UIKit
import HockeySDK

let rootURL = NSURL(string: "http://hackathon.reindeerjob.com")!
//let rootURL = NSURL(string: "https://codecombat.com:443/")!

@UIApplicationMain
class AppDelegate: UIResponder {

	// MARK: - Properties

	lazy var window: UIWindow? = {
		let window = UIWindow(frame: UIScreen.mainScreen().bounds)
		window.rootViewController = RootViewController()
		return window
	}()

	let reachability = Reachability(hostName: rootURL.host)
}


extension AppDelegate: UIApplicationDelegate {
	func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool {

		// Setup Hockey
		let hockey = BITHockeyManager.sharedHockeyManager()
		hockey.configureWithIdentifier("3428ced3f76216ff4074389af01a3ef7")
		hockey.startManager()
		hockey.authenticator.authenticateInstallation()

		// Custom User-Agent
		NSUserDefaults.standardUserDefaults().registerDefaults(["UserAgent": "CodeCombat-iPad"])

		// Initialize the IAP helper
		CodeCombatIAPHelper.sharedInstance

		// Start Reachability
		reachability.startNotifier()

		// Display window
		window?.makeKeyAndVisible()

		return true
	}
}
