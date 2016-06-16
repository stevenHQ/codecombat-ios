//
//  PlayViewController.swift
//  CodeCombat
//
//  Created by Michael Schmatz on 8/6/14.
//  Copyright (c) 2014 CodeCombat. All rights reserved.
//

import UIKit
import WebKit

//I have subclassed UIScrollView so we can scroll on the WKWebView
class PlayViewScrollView:UIScrollView, UIGestureRecognizerDelegate {
  func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    return true
  }
}
class PlayViewController: UIViewController {

  @IBOutlet weak var runButton: UIButton!
  @IBOutlet weak var submitButton: UIButton!
  @IBOutlet weak var redoButton: UIButton!
  @IBOutlet weak var undoButton: UIButton!
  @IBOutlet weak var keyboardButton: UIButton!
  @IBOutlet weak var resetCodeButton: UIButton!
  
  var levelName = ""
  var scrollView: UIScrollView!
  var webView: WKWebView?
  let editorContainerView = UIView()
  var textViewController: EditorTextViewController!
  var inventoryViewController: TomeInventoryViewController!
  var inventoryFrame: CGRect!
  let webManager = WebManager.sharedInstance
  let backgroundImage = UIImage(named: "play_background")!
  
  let lastSubmitString:String = ""
  
  override func viewDidLoad() {
    super.viewDidLoad()
    listenToNotifications()
    setupViews()
    NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(PlayViewController.onWebViewReloadedFromCrash), name: "webViewReloadedFromCrash", object: nil)
  }
  
  private func listenToNotifications() {
    //webManager.subscribe(self, channel: "sprite:speech-updated", selector: Selector("onSpriteSpeechUpdated:"))
    webManager.subscribe(self, channel: "tome:spell-loaded", selector: #selector(PlayViewController.onTomeSpellLoaded(_:)))
    webManager.subscribe(self, channel: "tome:winnability-updated", selector: #selector(PlayViewController.onTomeWinnabilityUpdated(_:)))
    let nc = NSNotificationCenter.defaultCenter()
    //additional notifications are listened to below concerning undo manager in setupEditor
    nc.addObserver(self, selector: #selector(PlayViewController.setUndoRedoEnabled), name: "textEdited", object: nil)
    NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(PlayViewController.onTextStorageFinishedTopLevelEditing), name: "textStorageFinishedTopLevelEditing", object: nil)
  }
  
  func unsubscribeFromEverything() {
    NSNotificationCenter.defaultCenter().removeObserver(self)
    WebManager.sharedInstance.unsubscribe(self)
  }
  
  deinit {
    print("PLAY VIEW CONTROLLER DE-INITED")
    textViewController.textView.parentTextViewController = nil
    webManager.unsubscribe(textViewController)
    webManager.unsubscribe(inventoryViewController)
  }
  
  func onTextStorageFinishedTopLevelEditing() {
    if getEscapedSourceString() != lastSubmitString {
      runButton.enabled = true
    } else {
      //show error text view here
    }
  }
  
  func setupViews() {
    let frameWidth = view.frame.size.width
    //let frameHeight = view.frame.size.height
    let aspectRatio:CGFloat = 1.56888
    let topBarHeight: CGFloat = 50
    let backgroundImageVerticalOverlap: CGFloat = 11
    editorContainerView.frame = CGRectMake(0, topBarHeight + frameWidth / aspectRatio - backgroundImageVerticalOverlap, frameWidth, backgroundImage.size.height)
    setupScrollView()
    setupInventory()
    setupEditor()
    setupBackgrounds()
    setupToolbar()
    setUndoRedoEnabled()
  }
  
  func setupScrollView() {
    scrollView = PlayViewScrollView(frame: view.frame)
    scrollView.contentSize = CGSizeMake(view.frame.size.width, editorContainerView.frame.origin.y + editorContainerView.frame.size.height)
    scrollView.addSubview(editorContainerView)
    scrollView.bounces = false
    scrollView.contentOffset = CGPoint(x: 0, y: 200)  // Helps for testing.
    view.insertSubview(scrollView, atIndex: 0)
  }
  
  func setupInventory() {
    let inventoryTopMargin: CGFloat = 51
    let inventoryBottomMargin: CGFloat = 25
    inventoryFrame = CGRectMake(0, inventoryTopMargin, 320, editorContainerView.frame.height - inventoryTopMargin - inventoryBottomMargin)
    inventoryViewController = TomeInventoryViewController()
    inventoryViewController.view.frame = inventoryFrame
    inventoryViewController.inventoryView.frame = CGRect(x: 0, y: 0, width: inventoryFrame.width, height: inventoryFrame.height)
    //helps to fix a scrolling bug
    scrollView.panGestureRecognizer.requireGestureRecognizerToFail(inventoryViewController.inventoryView.panGestureRecognizer)
    addChildViewController(inventoryViewController)
    editorContainerView.addSubview(inventoryViewController.view)
  }
  
  func setupEditor() {
    let editorVerticalMargin: CGFloat = 50
    let editorTextViewFrame = CGRectMake(370, editorVerticalMargin, 630, editorContainerView.frame.height - 2 * editorVerticalMargin)
    textViewController = EditorTextViewController()
    textViewController.view.frame = editorTextViewFrame
    
    textViewController.createTextViewWithFrame(editorTextViewFrame)
    scrollView.panGestureRecognizer.requireGestureRecognizerToFail(textViewController.dragGestureRecognizer)
    scrollView.panGestureRecognizer.requireGestureRecognizerToFail(textViewController.textView.panGestureRecognizer)
    addChildViewController(textViewController)
    editorContainerView.addSubview(textViewController.textView)
    let undoManager = textViewController.textStorage.undoManager
    let nc = NSNotificationCenter.defaultCenter()
    nc.addObserver(self, selector: #selector(PlayViewController.setUndoRedoEnabled), name: NSUndoManagerDidUndoChangeNotification, object: undoManager)
    nc.addObserver(self, selector: #selector(PlayViewController.setUndoRedoEnabled), name: NSUndoManagerDidRedoChangeNotification, object: undoManager)
  }

  func setupWebView() {
    webView = webManager.webView!
    webView!.hidden = false
    if webView != nil {
      scrollView.addSubview(webView!)
    }
  }
  
  func onWebViewReloadedFromCrash() {
    webView = WebManager.sharedInstance.webView!
  }
  
  func setupBackgrounds() {
    let editorBackground = UIImageView(image: backgroundImage)
    editorContainerView.addSubview(editorBackground)
    editorContainerView.sendSubviewToBack(editorBackground)

    let bottomBackground = UIImageView(image: UIImage(named: "play_background_bottom"))
    bottomBackground.frame.origin.y = view.frame.size.height - bottomBackground.frame.size.height
    view.insertSubview(bottomBackground, aboveSubview: editorContainerView)
    
    for button in [runButton, submitButton, redoButton, undoButton, keyboardButton, resetCodeButton] {
      view.insertSubview(button, aboveSubview: bottomBackground)
    }
  }
  
  func updateForLevel() {
    let levelID = LevelSettingsManager.sharedInstance.level
    if [.DungeonsOfKithgard, .GemsInTheDeep, .ShadowGuard, .KounterKithwise, .CrawlwaysOfKithgard, .ForgetfulGemsmith, .TrueNames, .FavorableOdds, .TheRaisedSword, .TheFirstKithmaze, .HauntedKithmaze, .DescendingFurther, .TheSecondKithmaze, .DreadDoor, .KnownEnemy, .MasterOfNames, .LowlyKithmen, .ClosingTheDistance, .TacticalStrike, .TheFinalKithmaze, .TheGauntlet, .KithgardGates, .CavernSurvival, .DefenseOfPlainswood, .WindingTrail].contains(levelID) {
      submitButton.setTitle("DONE", forState: .Normal)
      submitButton.setTitle("DONE", forState: .Highlighted)
      submitButton.setTitle("DONE", forState: .Selected)
      submitButton.setTitle("DONE", forState: .Disabled)
    }
  }

  func setupToolbar() {

  }

  func onSpriteSpeechUpdated(note:NSNotification) {
//    if let event = note.userInfo {
//      println("Setting speech before unveil!")
//      spriteMessageBeforeUnveil  = SpriteDialogue(
//        image: UIImage(named: "AnyaPortrait"),
//        spriteMessage: event["message"]! as String,
//        spriteName: event["spriteID"]! as String)
//    }
  }
  
  func onTomeSpellLoaded(note:NSNotification) {
    if let event = note.userInfo {
      let spell = event["spell"] as! NSDictionary
      let startingCode = spell["source"] as? String
      if startingCode != nil {
        textViewController.replaceTextViewContentsWithString(startingCode!)
        print("set code before load to \(startingCode!)")
        textViewController.textStorage.undoManager.removeAllActions()
        setUndoRedoEnabled()

      }
    }
  }
  
  func onTomeWinnabilityUpdated(note: NSNotification) {
    print("winnability updated \(note)")
    if let event = note.userInfo {
      let winnable = event["winnable"] as! Bool
      runButton.selected = !winnable
      submitButton.selected = winnable
    }
  }

  @IBAction func onCodeRun(sender: UIButton) {
    NSNotificationCenter.defaultCenter().postNotificationName("codeRun", object: nil)
    handleTomeSourceRequest()
    webManager.publish("tome:manual-cast", event: [:])
    scrollView.contentOffset = CGPoint(x: 0, y: 0)
    runButton.enabled = false
  }

  @IBAction func onCodeSubmitted(sender: UIButton) {
    handleTomeSourceRequest()
    webManager.publish("tome:manual-cast", event: ["realTime": true])
    scrollView.contentOffset = CGPoint(x: 0, y: 0)
  }
  
  @IBAction func onUndo(sender:UIButton) {
    textViewController.textStorage.undoManager.undo()
    textViewController.textView.setNeedsDisplay()
  }
  
  @IBAction func onRedo(sender:UIButton) {
    textViewController.textStorage.undoManager.redo()
    textViewController.textView.setNeedsDisplay()
  }
  
  @IBAction func onClickResetCode(sender:UIButton) {
    let titleMessage = NSLocalizedString("Are you sure?", comment:"")
    let messageString = NSLocalizedString("Reloading the original code will erase all of the code you've written. Are you sure?", comment:"")
    let alertController = UIAlertController(title: titleMessage, message: messageString, preferredStyle: .Alert)
    let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
    alertController.addAction(cancelAction)
    
    let resetAction = UIAlertAction(title: "Reset", style: .Destructive, handler: {(action) in
      NSNotificationCenter.defaultCenter().postNotificationName("codeReset", object: nil)
      self.webManager.publish("level:restart", event: [:])
    })
    alertController.addAction(resetAction)
    presentViewController(alertController, animated: true, completion: nil)
  }
  
  func setUndoRedoEnabled() {
    let undoManager = textViewController.textStorage.undoManager
    undoButton.enabled = undoManager.canUndo
    redoButton.enabled = undoManager.canRedo
  }
  
  func scrollToBottomOfScrollView() {
    let bottomOffset = CGPoint(x: 0, y: scrollView.contentSize.height - self.scrollView.frame.size.height)
    scrollView.setContentOffset(bottomOffset, animated: true)
  }
  
  @IBAction func toggleKeyboard(sender:UIButton) {
    if !textViewController.keyboardModeEnabled {
      scrollToBottomOfScrollView()
    }
    textViewController.toggleKeyboardMode()
  }

  func getEscapedSourceString() -> String {
    if textViewController.textView == nil {
      return ""
    }
    var escapedString = textViewController.textView.text.stringByReplacingOccurrencesOfString("\"", withString: "\\\"")
    escapedString = escapedString.stringByReplacingOccurrencesOfString("\n", withString: "\\n")
    return escapedString
  }
  func handleTomeSourceRequest(){
    let escapedString = getEscapedSourceString()
    lastSubmitString == escapedString
    let js = "if(currentView.tome.spellView) { currentView.tome.spellView.ace.setValue(\"\(escapedString)\"); } else { console.log('damn, no one was selected!'); }"
    //println(js)
    webManager.evaluateJavaScript(js, completionHandler: nil)
  }
}
