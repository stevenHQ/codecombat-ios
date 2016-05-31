//
//  GDWebViewController.swift
//  GDWebBrowserClient
//
//  Created by Alex G on 03.12.14.
//  Copyright (c) 2015 Alexey Gordiyenko. All rights reserved.
//

//MIT License
//
//Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import UIKit
import WebKit

enum GDWebViewControllerProgressIndicatorStyle {
    case ActivityIndicator
    case ProgressView
    case Both
    case None
}

@objc protocol GDWebViewControllerDelegate {
    optional func webViewController(webViewController: GDWebViewController, didChangeURL newURL: NSURL?)
    optional func webViewController(webViewController: GDWebViewController, didChangeTitle newTitle: NSString?)
    optional func webViewController(webViewController: GDWebViewController, didFinishLoading loadedURL: NSURL?)
    optional func webViewController(webViewController: GDWebViewController, decidePolicyForNavigationAction navigationAction: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> Void)
    optional func webViewController(webViewController: GDWebViewController, decidePolicyForNavigationResponse navigationResponse: WKNavigationResponse, decisionHandler: (WKNavigationResponsePolicy) -> Void)
    optional func webViewController(webViewController: GDWebViewController, didReceiveAuthenticationChallenge challenge: NSURLAuthenticationChallenge, completionHandler: (NSURLSessionAuthChallengeDisposition, NSURLCredential!) -> Void)
}

class GDWebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, GDWebViewNavigationToolbarDelegate {
    
    // MARK: Public Properties
    
    /** An object to serve as a delegate which conforms to GDWebViewNavigationToolbarDelegate protocol. */
    weak var delegate: GDWebViewControllerDelegate?
    
    /** The style of progress indication visualization. Can be one of four values: .ActivityIndicator, .ProgressView, .Both, .None*/
    var progressIndicatorStyle: GDWebViewControllerProgressIndicatorStyle = .Both
    
    /** A Boolean value indicating whether horizontal swipe gestures will trigger back-forward list navigations. The default value is false. */
    var allowsBackForwardNavigationGestures: Bool {
        get {
            return webView.allowsBackForwardNavigationGestures
        }
        set(value) {
            webView.allowsBackForwardNavigationGestures = value
        }
    }
    
    /** A boolean value if set to true shows the toolbar; otherwise, hides it. */
    var showsToolbar: Bool {
        set(value) {
            self.toolbarHeight = value ? 44 : 0
        }
        
        get {
            return self.toolbarHeight == 44
        }
    }
    
    /** A boolean value if set to true shows the refresh control (or stop control while loading) on the toolbar; otherwise, hides it. */
    var showsStopRefreshControl: Bool {
        get {
            return toolbarContainer.showsStopRefreshControl
        }
        
        set(value) {
            toolbarContainer.showsStopRefreshControl = value
        }
    }
    
    /** The navigation toolbar object (read-only). */
    var toolbar: GDWebViewNavigationToolbar {
        get {
            return toolbarContainer
        }
    }
    
    /** Boolean flag which indicates whether JavaScript alerts are allowed. Default is `true`. */
    var allowJavaScriptAlerts = true
    
    // MARK: Private Properties
    private var webView: WKWebView!
    private var progressView: UIProgressView!
    private var toolbarContainer: GDWebViewNavigationToolbar!
    private var toolbarHeightConstraint: NSLayoutConstraint!
    private var toolbarHeight: CGFloat = 0
    private var navControllerUsesBackSwipe: Bool = false
    lazy private var activityIndicator: UIActivityIndicatorView! = {
        var activityIndicator = UIActivityIndicatorView()
        activityIndicator.backgroundColor = UIColor(white: 0, alpha: 0.2)
        activityIndicator.activityIndicatorViewStyle = .WhiteLarge
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(activityIndicator)
        
        self.view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("|-0-[activityIndicator]-0-|", options: [], metrics: nil, views: ["activityIndicator": activityIndicator]))
        self.view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[topGuide]-0-[activityIndicator]-0-[toolbarContainer]|", options: [], metrics: nil, views: ["activityIndicator": activityIndicator, "toolbarContainer": self.toolbarContainer, "topGuide": self.topLayoutGuide]))
        return activityIndicator
    }()
    
    // MARK: Public Methods
    
    /**
    Navigates to an URL created from provided string.
    
    - parameter URLString: The string that represents an URL.
    */
    
    // TODO: Earlier `scheme` property was optional. Now it isn't true. Need to check that scheme is always
    
    func loadURLWithString(URLString: String) {
        if let URL = NSURL(string: URLString) {
            if (URL.scheme != "") && (URL.host != nil) {
                loadURL(URL)
            } else {
                loadURLWithString("http://\(URLString)")
            }
        }
    }
    
    /**
    Navigates to the URL.
    
    - parameter URL: The URL for a request.
    - parameter cachePolicy: The cache policy for a request. Optional. Default value is .UseProtocolCachePolicy.
    - parameter timeoutInterval: The timeout interval for a request, in seconds. Optional. Default value is 0.
    */
    func loadURL(URL: NSURL, cachePolicy: NSURLRequestCachePolicy = .UseProtocolCachePolicy, timeoutInterval: NSTimeInterval = 0) {
        webView.loadRequest(NSURLRequest(URL: URL, cachePolicy: cachePolicy, timeoutInterval: timeoutInterval))
    }
    
    /**
     Evaluates the given JavaScript string.
     - parameter javaScriptString: The JavaScript string to evaluate.
     - parameter completionHandler: A block to invoke when script evaluation completes or fails.
     
     The completionHandler is passed the result of the script evaluation or an error.
    */
    func evaluateJavaScript(javaScriptString: String, completionHandler: ((AnyObject?, NSError?) -> Void)?) {
        webView.evaluateJavaScript(javaScriptString, completionHandler: completionHandler)
    }
    
    /**
    Shows or hides toolbar.
    
    - parameter show: A Boolean value if set to true shows the toolbar; otherwise, hides it.
    - parameter animated: A Boolean value if set to true animates the transition; otherwise, does not.
    */
    func showToolbar(show: Bool, animated: Bool) {
        self.showsToolbar = show
        
        if toolbarHeightConstraint != nil {
            toolbarHeightConstraint.constant = self.toolbarHeight
            if animated {
                UIView.animateWithDuration(0.2, animations: { () -> Void in
                    self.view.layoutIfNeeded()
                })
            } else {
                self.view.layoutIfNeeded()
            }
        }
    }
    
    // MARK: GDWebViewNavigationToolbarDelegate Methods
    
    func webViewNavigationToolbarGoBack(toolbar: GDWebViewNavigationToolbar) {
        webView.goBack()
    }
    
    func webViewNavigationToolbarGoForward(toolbar: GDWebViewNavigationToolbar) {
        webView.goForward()
    }
    
    func webViewNavigationToolbarRefresh(toolbar: GDWebViewNavigationToolbar) {
        webView.reload()
    }
    
    func webViewNavigationToolbarStop(toolbar: GDWebViewNavigationToolbar) {
        webView.stopLoading()
    }
    
    // MARK: WKNavigationDelegate Methods
    
    func webView(webView: WKWebView, didCommitNavigation navigation: WKNavigation!) {
    }
    
    func webView(webView: WKWebView, didFailNavigation navigation: WKNavigation!, withError error: NSError) {
        showLoading(false)
        if error.code == NSURLErrorCancelled {
            return
        }
        
        showError(error.localizedDescription)
    }
    
    func webView(webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: NSError) {
        showLoading(false)
        if error.code == NSURLErrorCancelled {
            return
        }
        showError(error.localizedDescription)
    }
    
    func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!) {
        showLoading(false)
        backForwardListChanged()
        delegate?.webViewController?(self, didFinishLoading: webView.URL)
    }
    
    func webView(webView: WKWebView, didReceiveAuthenticationChallenge challenge: NSURLAuthenticationChallenge, completionHandler: (NSURLSessionAuthChallengeDisposition, NSURLCredential?) -> Void) {
        guard ((delegate?.webViewController?(self, didReceiveAuthenticationChallenge: challenge, completionHandler: { (disposition, credential) -> Void in
                completionHandler(disposition, credential)
            })) != nil)
        else {
            completionHandler(.PerformDefaultHandling, nil)
            return
        }
    }
    
    func webView(webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
    }
    
    func webView(webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        showLoading(true)
    }
    
    func webView(webView: WKWebView, decidePolicyForNavigationAction navigationAction: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> Void) {
        guard ((delegate?.webViewController?(self, decidePolicyForNavigationAction: navigationAction, decisionHandler: { (policy) -> Void in
                decisionHandler(policy)
                if policy == .Cancel {
                    self.showError("This navigation is prohibited.")
                }
            })) != nil)
        else {
            decisionHandler(.Allow);
            return
        }
    }
    
    func webView(webView: WKWebView, decidePolicyForNavigationResponse navigationResponse: WKNavigationResponse, decisionHandler: (WKNavigationResponsePolicy) -> Void) {
        guard ((delegate?.webViewController?(self, decidePolicyForNavigationResponse: navigationResponse, decisionHandler: { (policy) -> Void in
                decisionHandler(policy)
                if policy == .Cancel {
                    self.showError("This navigation response is prohibited.")
                }
            })) != nil)
        else {
            decisionHandler(.Allow)
            return
        }
    }
    
    // MARK: WKUIDelegate Methods
    
    func webView(webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: () -> Void) {
        if !allowJavaScriptAlerts {
            return
        }
        
        let alertController: UIAlertController = UIAlertController(title: message, message: nil, preferredStyle: .Alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: {(action: UIAlertAction) -> Void in
            completionHandler()
        }))
        
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    // MARK: Some Private Methods
    
    private func showError(errorString: String?) {
        let alertView = UIAlertController(title: "Error", message: errorString, preferredStyle: .Alert)
        alertView.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
        self.presentViewController(alertView, animated: true, completion: nil)
    }
    
    private func showLoading(animate: Bool) {
        if animate {
            if (progressIndicatorStyle == .ActivityIndicator) || (progressIndicatorStyle == .Both) {
                activityIndicator.startAnimating()
            }
            
            toolbar.loadDidStart()
        } else if activityIndicator != nil {
            if (progressIndicatorStyle == .ActivityIndicator) || (progressIndicatorStyle == .Both) {
                activityIndicator.stopAnimating()
            }
            
            toolbar.loadDidFinish()
        }
    }
    
    private func progressChanged(newValue: NSNumber) {
        if progressView == nil {
            progressView = UIProgressView()
            progressView.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(progressView)
            
            self.view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("|-0-[progressView]-0-|", options: [], metrics: nil, views: ["progressView": progressView]))
            self.view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[topGuide]-0-[progressView(2)]", options: [], metrics: nil, views: ["progressView": progressView, "topGuide": self.topLayoutGuide]))
        }
        
        progressView.progress = newValue.floatValue
        if progressView.progress == 1 {
            progressView.progress = 0
            UIView.animateWithDuration(0.2, animations: { () -> Void in
                self.progressView.alpha = 0
            })
        } else if progressView.alpha == 0 {
            UIView.animateWithDuration(0.2, animations: { () -> Void in
                self.progressView.alpha = 1
            })
        }
    }
    
    private func backForwardListChanged() {
        if self.navControllerUsesBackSwipe && self.allowsBackForwardNavigationGestures {
            self.navigationController?.interactivePopGestureRecognizer?.enabled = !webView.canGoBack
        }
        
        toolbarContainer.backButtonItem?.enabled = webView.canGoBack
        toolbarContainer.forwardButtonItem?.enabled = webView.canGoForward
    }
    
    // MARK: KVO
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        guard let keyPath = keyPath else {return}
        switch keyPath {
        case "estimatedProgress":
            if (progressIndicatorStyle == .ProgressView) || (progressIndicatorStyle == .Both) {
                if let newValue = change?[NSKeyValueChangeNewKey] as? NSNumber {
                    progressChanged(newValue)
                }
            }
        case "URL":
            delegate?.webViewController?(self, didChangeURL: webView.URL)
        case "title":
            delegate?.webViewController?(self, didChangeTitle: webView.title)
        default:
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
    
    // MARK: Overrides
    
    // Override this property getter to show bottom toolbar above other toolbars
    override var edgesForExtendedLayout: UIRectEdge {
        get {
            return UIRectEdge(rawValue: super.edgesForExtendedLayout.rawValue ^ UIRectEdge.Bottom.rawValue)
        }
        set {
            super.edgesForExtendedLayout = newValue
        }
    }
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up toolbarContainer
        self.view.addSubview(toolbarContainer)
        self.view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("|-0-[toolbarContainer]-0-|", options: [], metrics: nil, views: ["toolbarContainer": toolbarContainer]))
        self.view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:[toolbarContainer]-0-|", options: [], metrics: nil, views: ["toolbarContainer": toolbarContainer]))
        toolbarHeightConstraint = NSLayoutConstraint(item: toolbarContainer, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: toolbarHeight)
        toolbarContainer.addConstraint(toolbarHeightConstraint)
        
        // Set up webView
        self.view.addSubview(webView)
        self.view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("|-0-[webView]-0-|", options: [], metrics: nil, views: ["webView": webView]))
        self.view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[topGuide]-0-[webView]-0-[toolbarContainer]|", options: [], metrics: nil, views: ["webView": webView, "toolbarContainer": toolbarContainer, "topGuide": self.topLayoutGuide]))
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        webView.addObserver(self, forKeyPath: "estimatedProgress", options: .New, context: nil)
        webView.addObserver(self, forKeyPath: "URL", options: .New, context: nil)
        webView.addObserver(self, forKeyPath: "title", options: .New, context: nil)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        webView.removeObserver(self, forKeyPath: "estimatedProgress")
        webView.removeObserver(self, forKeyPath: "URL")
        webView.removeObserver(self, forKeyPath: "title")
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        if let navVC = self.navigationController {
            if let gestureRecognizer = navVC.interactivePopGestureRecognizer {
                navControllerUsesBackSwipe = gestureRecognizer.enabled
            } else {
                navControllerUsesBackSwipe = false
            }
        }
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        if navControllerUsesBackSwipe {
            self.navigationController?.interactivePopGestureRecognizer?.enabled = true
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        webView.stopLoading()
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.commonInit()
    }
    
    func commonInit() {
        webView = WKWebView()
        webView.navigationDelegate = self
        webView.UIDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        toolbarContainer = GDWebViewNavigationToolbar(delegate: self)
        toolbarContainer.translatesAutoresizingMaskIntoConstraints = false
    }
}
