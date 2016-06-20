//
//  TomeInventoryViewController.swift
//  CodeCombat
//
//  Created by Michael Schmatz on 8/11/14.
//  Copyright (c) 2014 CodeCombat. All rights reserved.
//

import UIKit

class TomeInventoryViewController: UIViewController, UIScrollViewDelegate, UIGestureRecognizerDelegate {
  private var inventory: TomeInventory!
  private var inventoryLoaded = false
  var inventoryView: UIScrollView!
  private var draggedView: UIView!
  private var draggedProperty: TomeInventoryItemProperty!
  
  init() {
    inventory = TomeInventory()
    super.init(nibName: "", bundle: nil)
  }
  
  required convenience init?(coder aDecoder: NSCoder) {
    self.init()
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    inventoryView = UIScrollView()
    inventoryView.delegate = self
    
    let DragAndDropRecognizer = UIPanGestureRecognizer(
      target: self,
      action: #selector(TomeInventoryViewController.handleDrag(_:)))
    DragAndDropRecognizer.delegate = self
    inventoryView.addGestureRecognizer(DragAndDropRecognizer)
    inventoryView.panGestureRecognizer.requireGestureRecognizerToFail(DragAndDropRecognizer)
    
    inventoryView.bounces = false
    inventoryView.backgroundColor = UIColor.clearColor()
    view.addSubview(inventoryView)
    
    addScriptMessageNotificationObservers()
  }
  
  func setUpInventory() {
    let subviewsToRemove = inventoryView.subviews 
    for var index = subviewsToRemove.count - 1; index >= 0; index -= 1 {
      subviewsToRemove[index].removeFromSuperview()
    }
    var itemHeight = 0
    let itemMargin = 3
    for item in inventory.items {
      let width = Int(inventoryView.frame.width) - itemMargin
      let height = Int(inventoryView.frame.height) - itemHeight - itemMargin
      let itemFrame = CGRect(x: itemMargin / 2, y: itemHeight + itemMargin / 2, width: width, height: height)
      let itemView = TomeInventoryItemView(item: item, frame: itemFrame)
      if itemView.showsProperties {
        inventoryView.addSubview(itemView)
        itemHeight += Int(itemView.frame.height) + itemMargin
      }
    }
    inventoryView.contentSize = CGSize(width: inventoryView.frame.width, height: CGFloat(itemHeight))
  }
  
  private func addScriptMessageNotificationObservers() {
//    let webManager = WebManager.sharedInstance
//    webManager.subscribe(self, channel: "tome:palette-cleared", selector: Selector("onInventoryCleared:"))
//    webManager.subscribe(self, channel: "tome:palette-updated", selector: Selector("onInventoryUpdated:"))
  }
  
  func onInventoryCleared(note: NSNotification) {
    //println("inventory cleared: \(note)")
  }
  
  func onInventoryUpdated(note: NSNotification) {
    if inventoryLoaded { return }
    inventoryLoaded = true
    inventory = TomeInventory()
    let userInfo = note.userInfo as! [String: AnyObject]
    let entryGroupsJSON = userInfo["entryGroups"] as! String
    let entryGroups = JSON.parse(entryGroupsJSON)
    for (entryGroupName, entryGroup) in entryGroups.asDictionary! {
      let entries = entryGroup["props"].asArray!
      let entryNames: [String] = entries.map({entry in entry["name"].asString!}) as [String]
      let entryNamesJSON = entryNames.joinWithSeparator("\", \"")
      var imageInfoData = entryGroup["item"].asDictionary!
      let imageURL = imageInfoData["imageURL"]!
      let itemDataJSON = "{\"name\":\"\(entryGroupName)\",\"programmableProperties\":[\"\(entryNamesJSON)\"],\"imageURL\":\"\(imageURL)\"}"
      let itemData = JSON.parse(itemDataJSON)
      let item = TomeInventoryItem(itemData: itemData)
      for entry in entries {
        let property = TomeInventoryItemProperty(propertyData: entry, primary: true)
        item.addProperty(property)
      }
      inventory.addInventoryItem(item)
    }
    setUpInventory()
  }
  
  func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    //Make more specific to simultaneous uipangesturerecognizers if other gesture recognizers fire unintentionally
    return true
  }
  
  func handleDrag(recognizer:UIPanGestureRecognizer) {
    if recognizer == inventoryView.panGestureRecognizer {
      return
    }
    let Parent = parentViewController as! PlayViewController
    //Change this to reference editor view controller, rather than editor view
    let EditorView = Parent.textViewController.textView
    let LocationInParentView = recognizer.locationInView(Parent.view)
    let LocationInEditorContainerView = recognizer.locationInView(Parent.editorContainerView)
    let locationInEditorTextView = recognizer.locationInView(Parent.textViewController.textView)
    switch recognizer.state {
      
    case .Began:
      //Find the item view which received the click
      let ItemView:TomeInventoryItemView! = itemViewAtLocation(recognizer.locationInView(inventoryView))
      if ItemView == nil || ItemView.tomeInventoryItemPropertyAtLocation(recognizer.locationInView(ItemView)) == nil {
        // This weird code is the way to get the drag and drop recognizer to send
        // failure to the scroll gesture recognizer
        recognizer.enabled = false
        recognizer.enabled = true
        break
      }
      recognizer.enabled = true
      let ItemProperty = ItemView.tomeInventoryItemPropertyAtLocation(recognizer.locationInView(ItemView))
      draggedProperty = ItemProperty
      let DragView = UILabel()
      DragView.font = EditorView.font
      let adjustedCodeSnippet = Parent.textViewController.replacePlaceholderInString(ItemProperty!.codeSnippetForLanguage("python")!, replacement: "")
      DragView.text = adjustedCodeSnippet
      DragView.sizeToFit()
      DragView.center = LocationInParentView
      DragView.backgroundColor = UIColor.clearColor()
      Parent.view.addSubview(DragView)
      draggedView = DragView
      Parent.textViewController.handleItemPropertyDragBegan()
      break
    case .Changed:
      let yDelta = LocationInParentView.y - draggedView.center.y
      draggedView.center = LocationInParentView
      Parent.textViewController.handleItemPropertyDragChangedAtLocation(locationInEditorTextView,
        locParentView: LocationInParentView,
        yDelta: yDelta)
      if EditorView.frame.contains(LocationInEditorContainerView) {
        var Snippet = draggedProperty.codeSnippetForLanguage("python")
        if Snippet != nil {
          Snippet = draggedProperty.name
        }
      } else {
        EditorView.removeLineDimmingOverlay()
      }
      break
    case .Ended:
      draggedView.removeFromSuperview()
      var Snippet = draggedProperty.codeSnippetForLanguage("python")
      if Snippet == nil {
        Snippet = draggedProperty.name
      }
      if EditorView.frame.contains(LocationInEditorContainerView) {
        Parent.textViewController.handleItemPropertyDragEndedAtLocation(locationInEditorTextView, code: Snippet!)
      } else {
        EditorView.removeDragHintView()
        EditorView.removeLineDimmingOverlay()
      }
      draggedView = nil
      
      break
    default:
      break
    }
  }
  
  func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
    if draggedView != nil {
      return false
    }
    if gestureRecognizer != inventoryView.panGestureRecognizer && gestureRecognizer is UIPanGestureRecognizer {
      if itemViewAtLocation(gestureRecognizer.locationInView(inventoryView)) == nil {
        return false
      }
    }
    return true
  }
  
  func itemViewAtLocation(location:CGPoint) -> TomeInventoryItemView! {
    var ItemView:TomeInventoryItemView! = nil
    for subview in inventoryView.subviews {
      if subview is TomeInventoryItemView && subview.frame.contains(location) {
        ItemView = subview as! TomeInventoryItemView
      }
    }
    return ItemView
  }
  
  override func loadView() {
    view = UIView(frame: UIScreen.mainScreen().bounds)
  }
  
}
