//
//  GameViewController.swift
//  CodeCombat
//
//  Created by Nick Winter on 10/24/14.
//  Copyright (c) 2014 CodeCombat. All rights reserved.
//

import UIKit

/// Main game view controller. A current user is required to initialize this view controller.
class GameViewController: UIViewController {

	// MARK: - Properties

	var user: User {
		didSet {
			updateUser()
		}
	}

	let webView: GameWebView = {
		let view = GameWebView()
		view.translatesAutoresizingMaskIntoConstraints = false
		return view
	}()


	// MARK: - Initializers

	init(user: User) {
		self.user = user
		super.init(nibName: nil, bundle: nil)
		updateUser()
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

    override func viewWillAppear(animated: Bool) {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(GameViewController.keyboardWillShow(_:)), name:UIKeyboardWillShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(GameViewController.keyboardWillHide(_:)), name:UIKeyboardWillHideNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(GameViewController.keyboardDidShow(_:)), name:UIKeyboardDidShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(GameViewController.keyboardDidHide(_:)), name:UIKeyboardDidHideNotification, object: nil)
    }

	// MARK: - UIViewController

	override func viewDidLoad() {
		super.viewDidLoad()

        webView.scrollView.bounces = false
		view.addSubview(webView)

		NSLayoutConstraint.activateConstraints([
			webView.leadingAnchor.constraintEqualToAnchor(view.leadingAnchor),
			webView.trailingAnchor.constraintEqualToAnchor(view.trailingAnchor),
			webView.topAnchor.constraintEqualToAnchor(view.topAnchor),
			webView.bottomAnchor.constraintEqualToAnchor(view.bottomAnchor)
		])
	}

    deinit {
        // 删除键盘监听
        print("删除键盘监听")
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

	// MARK: - Actions

	@objc private func signOut() {
		User.currentUser = nil
	}


	// MARK: - Private

	private func updateUser() {
		webView.user = user
	}
    
    /// 监听键盘收回
    func keyboardWillShow(notification: NSNotification) {
        print("键盘即将弹出")
    
    }
    
    /// 监听键盘收回
    func keyboardWillHide(notification: NSNotification) {
        print("键盘即将收回")

    }
    
    /// 监听键盘弹出
    func keyboardDidShow(notification: NSNotification) {
        print("键盘已经弹出")
        
        let info  = notification.userInfo!
        let value: AnyObject = info[UIKeyboardFrameEndUserInfoKey]!
        
        let rawFrame = value.CGRectValue()
        let keyboardFrame = view.convertRect(rawFrame, fromView: nil)
    }
    
    /// 监听键盘收回
    func keyboardDidHide(notification: NSNotification) {
        print("键盘已经收回")

    }


//  var webManager = WebManager.sharedInstance
//  var webView: WKWebView = WebManager.sharedInstance.webView!
//  var playViewController: PlayViewController?
//  var playLevelRoutePrefix = "/play/level/"
//  var memoryWarningView:MemoryWarningViewController!
//  var memoryWarningCountdownTimer:NSTimer!
//  var memoryWarningCountdownCounts = 0
//  let memoryWarningCountdownDuration = 5
//  var memoryWarningsReceived = 0
//  var memoryAlertController:UIAlertController!
//  var productBeingPurchased:SKProduct!
//  
//  override func viewDidLoad() {
//    super.viewDidLoad()
//    webView = WebManager.sharedInstance.webView!
//    view.addSubview(webView)
//    view.sendSubviewToBack(webView)
//    NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("listenToNotifications"), name: "webViewDidFinishNavigation", object: nil)
//    NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("onWebsiteNotReachable"), name: "websiteNotReachable", object: nil)
//    NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("onWebsiteReachable"), name: "websiteReachable", object: nil)
//    NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("onLoginFailure"), name: "loginFailure", object: nil)
//    NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("onWebViewReloadedFromCrash"), name: "webViewReloadedFromCrash", object: nil)
//  }
//  
//  func listenToNotifications() {
//    delay(0.1, closure: {
//      self.webManager.subscribe(self, channel: "router:navigated", selector: Selector("onNavigated:"))
//      self.webManager.subscribe(self, channel: "level:loading-view-unveiled", selector: Selector("onLevelStarted:"))
//      self.webManager.subscribe(self, channel: "auth:logging-out", selector: Selector("onLogout"))
//      self.webManager.subscribe(self, channel: "buy-gems-modal:update-products", selector: Selector("onBuyGemsModalUpdateProducts"))
//      self.webManager.subscribe(self, channel: "buy-gems-modal:purchase-initiated", selector: Selector("onBuyGemsModalPurchaseInitiated:"))
//      self.webManager.subscribe(self, channel: "auth:signed-up", selector: Selector("onSignedUp"))
//      //webManager.subscribe(self, channel: "supermodel:load-progress-changed", selector: Selector("onProgressUpdate:"))
//      NSNotificationCenter.defaultCenter().removeObserver(self, name: "webViewDidFinishNavigation", object: nil)
//    })
//  }
//  
//  func onSignedUp() {
//    print("Signed up!")
//    webManager.clearCredentials()
//  }
//  
//  func onBuyGemsModalUpdateProducts() {
//    //login to get auth cookie
//    WebManager.sharedInstance.loginToGetAuthCookie()
//    if CodeCombatIAPHelper.sharedInstance.productsDict.count != 0 {
//      sendIPadProductsToWebView()
//    } else {
//      CodeCombatIAPHelper.sharedInstance.requestProductsWithCompletionHandler({ (success, products) -> Void in
//        if success {
//          self.onBuyGemsModalUpdateProducts()
//        } else {
//          print("Failed to get list of products")
//        }
//      })
//    }
//    
//  }
//  
//  func onBuyGemsModalPurchaseInitiated(note:NSNotification) {
//    let productID = note.userInfo!["productID"] as! String
//    let desiredProduct = CodeCombatIAPHelper.sharedInstance.productsDict[productID]
//    print("WANTS TO BUY PRODUCT \(productID)")
//    if desiredProduct != nil {
//      productBeingPurchased = desiredProduct!
//      CodeCombatIAPHelper.sharedInstance.buyProduct(desiredProduct!)
//      NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("onProductPurchased:"), name: "productPurchased", object: nil)
//    }
//  }
//  
//  func onProductPurchased(note:NSNotification) {
//    NSNotificationCenter.defaultCenter().removeObserver(self, name: "productPurchased", object: nil)
//    productBeingPurchased = nil
//    var eventDict:[String:String] = [:]
//    if let userInfo = note.userInfo {
//      eventDict["productID"] = userInfo["productID"] as? String
//    }
//    webManager.publish("ipad:iap-complete", event: eventDict)
//    webManager.webView!.reload()
//  }
//  
//  func sendIPadProductsToWebView() {
//    var productsToSend:[[String:AnyObject]] = []
//    for product in CodeCombatIAPHelper.sharedInstance.productsDict.values {
//      var productDict:[String:AnyObject] = [:]
//      productDict["price"] = CodeCombatIAPHelper.sharedInstance.localizedPriceForProduct(product)
//      productDict["id"] = product.productIdentifier
//      productsToSend.append(productDict)
//    }
//    let productsObject = ["products":productsToSend]
//    webManager.publish("ipad:products", event: productsObject)
//  }
//  
//  //This listens for when the NSURLConnection login fails (aka password has changed, etc.)
//  func onLoginFailure() {
//    print("Login failed!")
//    if !WebManager.sharedInstance.currentCredentialIsPseudoanonymous() {
//      WebManager.sharedInstance.clearCredentials()
//    }
//    
//    dismissViewControllerAnimated(true, completion:nil)
//  }
//  
//  
//  
//  func onWebsiteNotReachable() {
//    print("Game view controller showing not reachable alert")
//    if memoryAlertController == nil {
//      let titleString = NSLocalizedString("Internet connection problem", comment:"")
//      let messageString = NSLocalizedString("We can't reach the CodeCombat server. Please check your connection and try again.", comment:"")
//      memoryAlertController = UIAlertController(title: titleString, message: messageString, preferredStyle: UIAlertControllerStyle.Alert)
//      memoryAlertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: { success in
//        self.memoryAlertController.dismissViewControllerAnimated(true, completion: nil)
//        self.memoryAlertController = nil
//      }))
//      presentViewController(memoryAlertController, animated: true, completion: nil)
//    }
//  }
//  
//  func onWebsiteReachable() {
//    if memoryAlertController != nil {
//      memoryAlertController.dismissViewControllerAnimated(true, completion: {
//        self.memoryAlertController = nil
//      })
//    }
//  }
//  
//  override func didReceiveMemoryWarning() {
//    memoryWarningsReceived++
//    if memoryWarningsReceived % 3 == 0 {
//      showMemoryWarningDialogue()
//    }
//    print("----------------- Received Memory Warning --------------")
//    NSURLCache.sharedURLCache().removeAllCachedResponses()
//    webManager.publish("ipad:memory-warning", event: [:])
//    super.didReceiveMemoryWarning()
//  }
//  
//  private func showMemoryWarningDialogue() {
//    if memoryWarningView != nil {
//      memoryWarningCountdownCounts = memoryWarningCountdownDuration
//      return
//    }
//    memoryWarningView = MemoryWarningViewController(nibName: "MemoryWarningViewController", bundle:nil)
//    addChildViewController(memoryWarningView)
//    var warningViewFrame = memoryWarningView.view.frame
//    warningViewFrame.origin.y = 50
//    warningViewFrame.origin.x = (view.bounds.width - warningViewFrame.width)/2
//    memoryWarningView.view.frame = warningViewFrame
//    memoryWarningView.view.layer.cornerRadius = 5
//    memoryWarningView.view.layer.masksToBounds = true
//    memoryWarningView.view.layer.borderColor = UIColor.blackColor().CGColor
//    memoryWarningView.view.layer.borderWidth = 2
//    view.addSubview(memoryWarningView.view)
//    memoryWarningCountdownCounts = memoryWarningCountdownDuration
//    memoryWarningCountdownTimer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: Selector("countDownMemoryWarning"), userInfo: nil, repeats: true)
//  }
//  
//  func countDownMemoryWarning() {
//    memoryWarningCountdownCounts--
//    print("Counting down!")
//    if memoryWarningCountdownCounts == 0 {
//      memoryWarningCountdownTimer.invalidate()
//      UIView.animateWithDuration(2, animations: {
//        self.memoryWarningView.view.alpha = 0
//        }, completion: { success in
//          self.memoryWarningView.view.removeFromSuperview()
//          self.memoryWarningView.removeFromParentViewController()
//          self.memoryWarningCountdownCounts = self.memoryWarningCountdownDuration
//          self.memoryWarningView = nil
//      })
//    }
//  }
//  
//  func onWebViewReloadedFromCrash() {
//    print("GameViewController going to reload its webview \(webManager.webView)")
//    webView = webManager.webView!
//    if webView.superview == view {
//      view.sendSubviewToBack(webView)
//    }
//    displayWebViewCrashedAlert()
//  }
//  
//  func displayWebViewCrashedAlert() {
//    let titleString = NSLocalizedString("The graphics layer ran out of memory!", comment:"")
//    let messageString = NSLocalizedString("The graphics layer ran out of memory and crashed! Don't worry, just hang on and wait for the level to reload.", comment:"")
//    let alertController = UIAlertController(title: titleString, message: messageString, preferredStyle: .Alert)
//    let OKAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
//    alertController.addAction(OKAction)
//    self.presentViewController(alertController, animated: true, completion: nil)
//  }
//  
//  deinit {
//    WebManager.sharedInstance.unsubscribe(self)
//  }
//  
//  func onLogout() {
//    webManager.clearCredentials()
//    webManager.unsubscribe(self)
//    NSNotificationCenter.defaultCenter().removeObserver(self)
//    webManager.removeAllUserScripts()
//    dismissViewControllerAnimated(true, completion: nil)
//  }
//  
//  private func loadLevel(levelSlug:String) {
//    WebManager.sharedInstance.publish("router:navigate", event: ["route": "/play/level/\(levelSlug)"])
//  }
//  
//  private func loadWorldMap() {
//    WebManager.sharedInstance.publish("router:navigate", event: ["route": "/play"])
//  }
//  
//  private func isRouteLevel(route: String) -> Bool {
//    return route.rangeOfString(playLevelRoutePrefix, options: NSStringCompareOptions.LiteralSearch) != nil
//  }
//  
//  private func routeLevelName(route:String) -> String {
//    if !isRouteLevel(route) {
//      return ""
//    } else {
//      let substringIndex = route.startIndex.advancedBy(playLevelRoutePrefix.characters.count)
//      return route.substringFromIndex(substringIndex)
//    }
//  }
//  
//  private func updateFrame(route: String) {
//    var webViewFrame = CGRectMake(0, 0, 1024, 768)  // Full-size
//    if isRouteLevel(route) {
//      let topBarHeight: CGFloat = 50
//      webViewFrame = CGRectMake(0, 0, 1024, topBarHeight + 1024 * (589 / 924))  // Full-width Surface, preserving aspect ratio.
//    }
//    WebManager.sharedInstance.webView!.frame = webViewFrame
//  }
//  
//  private func adjustPlayView(route: String) {
//    if isRouteLevel(route) {
//      let currentLevelName = routeLevelName(route)
//      let mainStoryboard = UIStoryboard(name: "Main", bundle: NSBundle.mainBundle())
//      playViewController = mainStoryboard.instantiateViewControllerWithIdentifier("PlayViewController") as? PlayViewController
//      playViewController?.view  // Access this early to get it set up and listening for events.
//      playViewController!.levelName = currentLevelName
//      if let newLevel = LevelName(rawValue: currentLevelName) {
//        LevelSettingsManager.sharedInstance.level = newLevel
//      } else {
//        LevelSettingsManager.sharedInstance.level = .Unknown
//      }
//      playViewController!.updateForLevel()
//      print("Created a playViewController for \(route)")
//    }
//    else {
//      print("Route is not a level \(route), so dismissing playViewController \(playViewController), have presentedViewController \(presentedViewController)")
//      LevelSettingsManager.sharedInstance.level = .Unknown
//      if presentedViewController != nil {
//        dismissViewControllerAnimated(false, completion: nil)
//        playViewController?.unsubscribeFromEverything()
//        playViewController = nil
//        view.addSubview(webView)
//      }
//    }
//  }
//  
//  func onNavigated(note: NSNotification) {
//    print("onNavigated:", note)
//    if let event = note.userInfo {
//      let route = event["route"]! as! String
//      updateFrame(route)
//      adjustPlayView(route)
//    }
//  }
//
//  func onLevelStarted(note: NSNotification) {
//    if presentedViewController != nil {
//      print("Hmmm, trying to start level again?");
//    } else {
//      playViewController!.setupWebView()
//      presentViewController(playViewController!, animated: false, completion: nil)
//      print("Now we are presenting \(presentedViewController)")
//    }
//  }
}
