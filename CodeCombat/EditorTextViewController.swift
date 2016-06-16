//
//  EditorTextViewController.swift
//  CodeCombat
//
//  Created by Michael Schmatz on 9/15/14.
//  Copyright (c) 2014 CodeCombat. All rights reserved.
//

import UIKit

class EditorTextViewController: UIViewController, UITextViewDelegate, UIGestureRecognizerDelegate, StringPickerPopoverDelegate, NumberPickerPopoverDelegate{
  let textStorage = EditorTextStorage()
  let textContainer = NSTextContainer()
  
  var draggedLabel:UILabel!
  var draggedCharacterRange:NSRange!
  var highlightedLineNumber = -1
  
  var dragGestureRecognizer:UIPanGestureRecognizer!
  var tapGestureRecognizer:UITapGestureRecognizer!
  var dragOverlayLabels:[Int:UILabel] = Dictionary<Int,UILabel>()
  var originalDragOverlayLabelOffsets:[Int:CGFloat] = Dictionary<Int,CGFloat>()
  
  var textView:EditorTextView!
  var keyboardModeEnabled:Bool {
    return textView.keyboardModeEnabled
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    setupGestureRecognizers()
    setupSubscriptionsAndObservers()
  }
  
  private func setupGestureRecognizers() {
    dragGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(EditorTextViewController.onDrag(_:)))
    dragGestureRecognizer.delegate = self
    tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(EditorTextViewController.onTap(_:)))
    tapGestureRecognizer.delegate = self
    tapGestureRecognizer.requireGestureRecognizerToFail(dragGestureRecognizer)
  }
  
  func setupSubscriptionsAndObservers() {
    WebManager.sharedInstance.subscribe(self, channel: "tome:highlight-line", selector: #selector(EditorTextViewController.onSpellStatementIndexUpdated(_:)))
    WebManager.sharedInstance.subscribe(self, channel: "problem:problem-created", selector: #selector(EditorTextViewController.onProblemCreated(_:)))
    NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(EditorTextViewController.onCodeRun), name: "codeRun", object: nil)
    NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(EditorTextViewController.onCodeReset), name: "codeReset", object: nil)
    NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(EditorTextViewController.onTextStorageFinishedTopLevelEditing), name: "textStorageFinishedTopLevelEditing", object: nil)
    NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(EditorTextViewController.onKeyboardHide), name: UIKeyboardDidHideNotification, object: nil)
  }
  
  deinit {
    NSNotificationCenter.defaultCenter().removeObserver(self)
  }
  
  func onKeyboardHide() {
    textView.selectable = false
    textView.editable = false
  }
  
  func onSpellStatementIndexUpdated(note:NSNotification) {
    if let event = note.userInfo {
      var lineIndex = event["line"]! as! Int
      lineIndex++
      if lineIndex != highlightedLineNumber {
        highlightedLineNumber = lineIndex
        textView.highlightLineNumber(lineIndex)
      }
    }
  }
  
  func onProblemCreated(note:NSNotification) {
    if let event = note.userInfo {
      var lineIndex = event["line"]! as! Int
      let errorText = event["text"]! as! String
      lineIndex++
      textView.addUserCodeProblemGutterAnnotationOnLine(lineIndex, message: errorText)
      textView.highlightUserCodeProblemLine(lineIndex)
    }
  }
  
  func onTap(recognizer:UITapGestureRecognizer) {
    if recognizer == tapGestureRecognizer {
      let tappedCharacterIndex = textView.characterIndexAtPoint(recognizer.locationInView(textView))
      if textView.keyboardModeEnabled {
        recognizer.enabled = false
        recognizer.enabled = true
        return
      }
      if textStorage.characterIsPartOfString(tappedCharacterIndex) {
        let stringRange = textStorage.stringRangeContainingCharacterIndex(tappedCharacterIndex)
        switch LevelSettingsManager.sharedInstance.level {
        case .TrueNames:
          createStringPickerPopoverWithChoices(["\"Brak\"","\"Treg\""], characterRange: stringRange, delegate: self)
        case .FavorableOdds:
          createStringPickerPopoverWithChoices(["\"Krug\"","\"Grump\""], characterRange: stringRange, delegate: self)
        case .TheRaisedSword:
          createStringPickerPopoverWithChoices(["\"Gurt\"","\"Rig\"","\"Ack\""], characterRange: stringRange, delegate: self)
        default:
          break
        }
      } else if let variableRange = textStorage.characterIsPartOfDefinedVariable(tappedCharacterIndex) {
        switch LevelSettingsManager.sharedInstance.level {
        case .LowlyKithmen, .ClosingTheDistance, .KnownEnemy,.MasterOfNames, .TacticalStrike, .TheFinalKithmaze, .TheGauntlet:
          var variables = textStorage.getDefinedVariableNames()
          let theIndex = textStorage.string.startIndex.advancedBy(variableRange.location + variableRange.length + 1)
          let substringBeforeOverlay = textStorage.string.substringToIndex(theIndex)
          variables = variables.filter({
            return substringBeforeOverlay.rangeOfString($0) != nil
          })
          createStringPickerPopoverWithChoices(variables, characterRange: variableRange, delegate: self)
          break
        default:
          break
        }
      } else if textStorage.characterIsPartOfNumber(tappedCharacterIndex) {
        let numberRange = textStorage.stringRangeContainingCharacterIndex(tappedCharacterIndex)
        switch LevelSettingsManager.sharedInstance.level {
        case .KithgardGates:
          createNumberPickerPopover(characterRange: numberRange, delegate: self)
        default:
          break
        }
      }
    }
  }
  
  
  func onCodeRun() {
    textView.clearCodeProblemGutterAnnotations()
    textView.removeCurrentLineNumberHighlight()
    textView.clearErrorMessageView()
    textView.removeUserCodeProblemLineHighlights()
  }
  
  func onCodeReset() {
    textView.clearCodeProblemGutterAnnotations()
    textView.removeCurrentLineNumberHighlight()
    textView.clearErrorMessageView()
    textView.removeUserCodeProblemLineHighlights()
  }
  
  func onDrag(recognizer:UIPanGestureRecognizer) {
    if recognizer != textView.panGestureRecognizer {
      if textView.keyboardModeEnabled {
        recognizer.enabled = false
        recognizer.enabled = true
        return
      }
      if textView.keyboardModeEnabled {
        print("Dragging when in text view!")
      }
      var locationInParentView = recognizer.locationInView(parentViewController!.view)
      locationInParentView.y += (textView.lineSpacing + textView.font!.lineHeight) / 2
      let locationInTextView = recognizer.locationInView(textView)
      switch recognizer.state {
      case .Began:
        let lineFragmentRect = getLineFragmentRectForDrag(locationInTextView)
        let characterRange = getCharacterRangeForLineFragmentRect(lineFragmentRect)
        let fragmentParagraphRange = (textStorage.string as NSString).paragraphRangeForRange(characterRange)
        draggedLabel = createDraggedLabel(lineFragmentRect, loc: locationInParentView, fragmentCharacterRange: characterRange)
        draggedCharacterRange = fragmentParagraphRange
        parentViewController!.view.addSubview(draggedLabel)
        textView.draggedLineNumber = lineNumberForDraggedCharacterRange(characterRange)
        
        textView.createViewsForAllLinesExceptDragged(lineFragmentRect, draggedCharacterRange: characterRange)
        textStorage.makeTextClear()
        NSNotificationCenter.defaultCenter().postNotificationName("overlayHideRequest", object: nil)
        textView.createDeletionOverlayView()
        break
      case .Changed:
        let yDelta = locationInParentView.y - draggedLabel.center.y
        textView.adjustLineViewsForDragLocation(locationInTextView)
        scrollWhileDraggingIfNecessary(locationInParentView, yDelta: yDelta)
        draggedLabel.center = locationInParentView
        hideOrShowDeleteOverlay()
        break
      case .Ended:
        textView.clearLineOverlayLabels()
        if draggedLineInDeletionZone() {
          deleteDraggedLine()
        } else {
          shiftAroundLines(locationInTextView)
        }
        //These eventually should run only when the code significantly changes
        NSNotificationCenter.defaultCenter().postNotificationName("overlayUnhideRequest", object: nil)
        textView.removeCurrentLineNumberHighlight()
        textView.clearCodeProblemGutterAnnotations()
        textView.removeUserCodeProblemLineHighlights()
        textView.removeDeletionOverlayView()
        draggedLabel.removeFromSuperview()
        draggedLabel = nil
        break
      default:
        break
      }
    }
  }
  
  func handleItemPropertyDragBegan() {
    textView.drawDragHintViewOnLastLine()
  }
  
  func handleItemPropertyDragChangedAtLocation(locTextView:CGPoint, locParentView:CGPoint, yDelta:CGFloat) {
    scrollWhileDraggingIfNecessary(locParentView, yDelta: yDelta)
    textView.slightlyHighlightLineUnderLocation(locTextView)
  }
  
  func handleItemPropertyDragEndedAtLocation(location:CGPoint, code:String) {
    textView.removeLineDimmingOverlay()
    textView.removeDragHintView()
    
    let storage = textStorage as EditorTextStorage
    
    let dragPoint = CGPoint(x: 0, y: location.y)
    let nearestGlyphIndex = textView.layoutManager.glyphIndexForPoint(dragPoint,
      inTextContainer: textContainer) //nearest glyph index
    //This may cause some really really weird bugs if glyphs and character indices don't correspond.
    let nearestCharacterIndex = textView.layoutManager.characterIndexForGlyphAtIndex(nearestGlyphIndex)
    
    let draggedOntoLine = textView.lineNumberUnderPoint(location)
    
    var numberOfNewlinesBeforeGlyphIndex = 1
    for var index = 0; index < nearestGlyphIndex; numberOfNewlinesBeforeGlyphIndex++ {
      index = NSMaxRange((storage.string as NSString).lineRangeForRange(NSRange(location: index, length: 0)))
    }
    
    var totalLinesInDoc = 1
    for var index = 0; index < storage.string.characters.count; totalLinesInDoc++ {
      index = NSMaxRange((storage.string as NSString).lineRangeForRange(NSRange(location: index, length: 0)))
    }
    
    //let characterAtGlyphIndex = (storage.string as NSString).characterAtIndex(nearestGlyphIndex)
    //let characterBeforeGlyphIndex = (storage.string as NSString).characterAtIndex(nearestGlyphIndex - 1)
    var stringToInsert = code
    //var newlinesToInsert = draggedOntoLine - numberOfNewlinesBeforeGlyphIndex
    //DO SPECIAL EDITS FOR CODE RIGHT HERE
    switch LevelSettingsManager.sharedInstance.level {
    case .LowlyKithmen, .ClosingTheDistance, .MasterOfNames, .TacticalStrike, .TheFinalKithmaze, .TheGauntlet, .KithgardGates:
      if LevelSettingsManager.sharedInstance.language == .Python {
        if code == "self.findNearestEnemy()" {
          stringToInsert = "${variable} = " + code
        } else if code.hasPrefix("self.buildXY") {
          stringToInsert = "self.buildXY(${d}, 36, 34)"
        }
      }
      break
    default:
      break
    }
    
    //Check if code contains a placeholder
    if codeContainsPlaceholder(stringToInsert) {
      print(stringToInsert)
      let placeholderReplacement = getPlaceholderWidthString(stringToInsert)
      stringToInsert = replacePlaceholderInString(stringToInsert, replacement: placeholderReplacement)
    }
    let numberOfLinesInDocument = textView.numberOfLinesInDocument()
    print("Dragged onto line \(draggedOntoLine), \(numberOfLinesInDocument) lines total")
    //Check if dragging onto an empty line in between two other lines of code.
    stringToInsert = fixIndentationLevelForPython(nearestCharacterIndex, lineNumber: draggedOntoLine, rawString: stringToInsert)
    //let newline = 10 as unichar
    //Adjust code to match indentation level and other languages
    let startOfDraggedLineCharacterIndex = textView.characterIndexForStartOfLine(draggedOntoLine)
    
    if draggedOntoLine > numberOfLinesInDocument {
      for var i=numberOfLinesInDocument; i < draggedOntoLine; i++ {
        stringToInsert = "\n" + stringToInsert
      }
      storage.replaceCharactersInRange(NSRange(location: startOfDraggedLineCharacterIndex - 1, length: 0), withString: stringToInsert)
    } else {
      if (storage.string as NSString).characterAtIndex(startOfDraggedLineCharacterIndex) != 10 {
        stringToInsert = stringToInsert + "\n"
      }
      storage.replaceCharactersInRange(NSRange(location: startOfDraggedLineCharacterIndex, length: 0), withString: stringToInsert)
    }
    //textView.setNeedsDisplay()
  }
  
  func codeContainsPlaceholder(code:String) -> Bool {
    let error:NSErrorPointer = nil
    let regex: NSRegularExpression?
    do {
      regex = try NSRegularExpression(pattern: "\\$\\{.*\\}", options: [])
    } catch let error1 as NSError {
      error.memory = error1
      regex = nil
    }
    let matches = regex!.matchesInString(code, options: [], range: NSRange(location: 0, length: code.characters.count))
    return matches.count > 0
  }
  
  func fixIndentationLevelForPython(firstCharacterIndex:Int, lineNumber:Int, rawString:String) -> String {
    let numberOfSpacesForIndentation = 4
    var indentationLevel = indentationLevelOfLine(lineNumber - 1)
    //58 is ASCII for :
    if firstNonWhitespaceCharacterBeforeCharacterIndex(firstCharacterIndex) == 58 {
      indentationLevel++
    }
    
    let stringToReturn = String(count: numberOfSpacesForIndentation * indentationLevel, repeatedValue: " " as Character) + rawString
    print("Returning string \(stringToReturn)")
    return stringToReturn
  }
  
  private func firstNonWhitespaceCharacterBeforeCharacterIndex(index:Int) -> unichar {
    let storage = textStorage as EditorTextStorage
    
    var firstNonWhitespaceCharacter = unichar(10)
    for var charIndex = index; charIndex > 0; charIndex-- {
      let character = (storage.string as NSString).characterAtIndex(charIndex)
      if !NSCharacterSet.whitespaceAndNewlineCharacterSet().characterIsMember(character) {
        firstNonWhitespaceCharacter = character
        break
      }
    }
    return firstNonWhitespaceCharacter
  }
  
  func replacePlaceholderInString(code:String, replacement:String) -> String {
    let error:NSErrorPointer = nil
    let regex: NSRegularExpression?
    do {
      regex = try NSRegularExpression(pattern: "\\$\\{.*\\}", options: [])
    } catch let error1 as NSError {
      error.memory = error1
      regex = nil
    }
    let matches = regex!.matchesInString(code, options: [], range: NSRange(location: 0, length: code.characters.count))
    if matches.count == 0 {
      return code
    }
    let firstMatch = matches[0] 
    let newString = NSString(string: code).stringByReplacingCharactersInRange(firstMatch.range, withString: replacement)
    return newString
  }
  
  private func indentationLevelOfLine(lineNumber:Int) -> Int {
    let storage = textStorage as EditorTextStorage
    if lineNumber <= 0 {
      return 0
    } else {
      let lines = storage.string.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet())
      let line = lines[min(lineNumber - 1, lines.count - 1)] as NSString
      var spacesCount = 0
      for var charIndex = 0; charIndex < line.length; charIndex++ {
        let character = line.characterAtIndex(charIndex)
        if NSCharacterSet.whitespaceCharacterSet().characterIsMember(character) {
          spacesCount++
        } else {
          break
        }
      }
      let indentationLevel = spacesCount / 4
      return indentationLevel
    }
  }
  
  func getPlaceholderWidthString(code:String) -> String {
    switch LevelSettingsManager.sharedInstance.level {
    case .KithgardGates:
      return "${eeee}"
    default:
      return "${1:d}"
    }
  }
  
  func getArgumentOverlays() -> [(String, NSRange)] {
    return textStorage.findArgumentOverlays()
  }
  
  func createStringPickerPopoverWithChoices(choices:[String], characterRange:NSRange, delegate:StringPickerPopoverDelegate) {
    let stringPickerViewController = ArgumentStringPickerPopoverViewController(stringChoices: choices, characterRange:characterRange)
    stringPickerViewController.pickerDelegate = delegate
    let glyphRange = textView.layoutManager.glyphRangeForCharacterRange(characterRange, actualCharacterRange: nil)
    var boundingRect = textView.layoutManager.boundingRectForGlyphRange(glyphRange, inTextContainer: textContainer)
    boundingRect.origin.y += textView.lineSpacing
    let popover = UIPopoverController(contentViewController: stringPickerViewController)
    popover.setPopoverContentSize(CGSize(width: 100, height: stringPickerViewController.rowHeight*choices.count), animated: true)
    popover.presentPopoverFromRect(boundingRect, inView: textView, permittedArrowDirections: [.Down, .Up], animated: true)
  }
  
  func createNumberPickerPopover(characterRange characterRange:NSRange, delegate:NumberPickerPopoverDelegate) {
    let picker = NumberPickerPopoverViewController(nibName: "NumberPickerPopoverViewController", bundle: nil)
    picker.pickerDelegate = self
    picker.characterRange = characterRange
    let glyphRange = textView.layoutManager.glyphRangeForCharacterRange(characterRange, actualCharacterRange: nil)
    var boundingRect = textView.layoutManager.boundingRectForGlyphRange(glyphRange, inTextContainer: textContainer)
    boundingRect.origin.y += textView.lineSpacing
    let popover = UIPopoverController(contentViewController: picker)
    popover.setPopoverContentSize(CGSize(width: 330, height: 400), animated: true)
    popover.presentPopoverFromRect(boundingRect, inView: textView, permittedArrowDirections: [.Down, .Up], animated: true)
    
  }
  func didSelectNumber(number: Int, characterRange: NSRange) {
    textStorage.replaceCharactersInRange(characterRange, withString: String(number))
  }
  
  func replaceCharactersInCharacterRange(characterRange:NSRange, str:String) {
    textStorage.replaceCharactersInRange(characterRange, withString: str)
  }
  
  func stringWasSelectedByStringPickerPopover(selected:String, characterRange:NSRange) {
    replaceCharactersInCharacterRange(characterRange, str: selected)
  }
  
  func onTextStorageFinishedTopLevelEditing() {
    textView?.removeCurrentLineNumberHighlight()
    ensureNewlineAtEndOfCode()
  }
  
  func toggleKeyboardMode() {
    textView.toggleKeyboardMode()
  }
  
  func ensureNewlineAtEndOfCode() {
    if !textStorage.string.hasSuffix("\n") {
      textStorage.beginEditing()
      textStorage.appendAttributedString(NSAttributedString(string: "\n"))
      textStorage.endEditing()
    }
  }
  
  func textViewDidEndEditing(textView: UITextView) {
    ensureNewlineAtEndOfCode()
    toggleKeyboardMode()
  }
  
  private func getLineFragmentRectForDrag(dragLocation:CGPoint) -> CGRect {
    let nearestGlyphIndexToDrag = textView.layoutManager.glyphIndexForPoint(dragLocation, inTextContainer: textContainer)
    var effectiveGlyphRange:NSRange = NSRange(location:0, length:0)
    let lineFragmentRectToDrag = textView.layoutManager.lineFragmentRectForGlyphAtIndex(nearestGlyphIndexToDrag, effectiveRange: &effectiveGlyphRange)
    return lineFragmentRectToDrag
  }
  
  private func getCharacterRangeForLineFragmentRect(lineFragmentRect:CGRect) -> NSRange {
    let glyphRange = textView.layoutManager.glyphRangeForBoundingRect(lineFragmentRect, inTextContainer: textContainer)
    let characterRange = textView.layoutManager.characterRangeForGlyphRange(glyphRange, actualGlyphRange: nil)
    return characterRange
  }
  
  func getAttributedStringForCharacterRange(range:NSRange) -> NSAttributedString {
    return textStorage.attributedStringStore.attributedSubstringFromRange(range)
  }
  
  private func createDraggedLabel(lineFragmentRect:CGRect, loc:CGPoint, fragmentCharacterRange:NSRange) -> UILabel {
    let label = textView.createLineLabel(lineFragmentRect, fragmentCharacterRange: fragmentCharacterRange)
    label.center = loc
    return label
  }
  
  private func hideOrShowDeleteOverlay() {
    if draggedLineInDeletionZone() {
      textView.showDeletionOverlayView()
    } else {
      textView.hideDeletionOverlayView()
    }
  }
  
  private func draggedLineInDeletionZone() -> Bool {
    return draggedLabel.center.x > parentViewController!.view.bounds.maxX - textView.deletionOverlayWidth
  }
  
  private func deleteDraggedLine() {
    textStorage.beginEditing()
    //let draggedLineString:NSString = (textStorage.string as NSString).substringWithRange(draggedCharacterRange).stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
    if draggedCharacterRange.location != 0 {
      textStorage.replaceCharactersInRange(draggedCharacterRange, withString: "")
    } else {
      textStorage.replaceCharactersInRange(draggedCharacterRange, withString: "\n")
    }
    textStorage.endEditing()
    /*if draggedLineString == "loop:" {
      println("Reindenting lines below")
      textStorage.beginEditing()
      removeOneIndentFromCharactersStartingFromLocation(draggedCharacterRange.location)
      textStorage.endEditing()
    }*/
    
    textView.setNeedsDisplay()
  }
  
  private func removeOneIndentFromCharactersStartingFromLocation(loc:Int) {
    var currentLocation = loc
    if currentLocation == 0 {
      currentLocation-- //to correct for this script
    }
    var stringLength = textStorage.length
    var currentIndentationLevel = -1
    while (currentLocation < stringLength && currentLocation != NSNotFound ) {
      //probably an off by one error
      stringLength = textStorage.length
      currentLocation++
      let lineEndLocation = (textStorage.string as NSString).rangeOfCharacterFromSet(NSCharacterSet.newlineCharacterSet(), options: NSStringCompareOptions(), range: NSRange(location: currentLocation, length: stringLength - (currentLocation))).location
      if lineEndLocation == NSNotFound {
        break
      }
      let line = lineNumberForDraggedCharacterRange(NSRange(location: lineEndLocation, length: 1))
      print("String is on line \(line)")
      let indentationLevel = indentationLevelOfLine(line)
      if currentIndentationLevel == -1 {
        currentIndentationLevel = indentationLevel
      }
      let lineRange = NSRange(location: currentLocation, length: lineEndLocation - currentLocation)
      var lineString = (textStorage.string as NSString).substringWithRange(lineRange)
      if currentIndentationLevel >= indentationLevel {
        currentIndentationLevel = indentationLevel
        print("Reindenting to level \(indentationLevel - 1)")
        lineString = reindentString(lineString, indentationLevel: indentationLevel - 1)
      }
      //reindent line
      textStorage.replaceCharactersInRange(lineRange, withString: lineString)
      currentLocation = lineRange.location + lineRange.length + (lineString.characters.count - lineRange.length)
    }
  }
  
  
  
  private func shiftAroundLines(dragEndLocation:CGPoint) {
    //get the text underneath the drag end
    let characterIndexUnderDrag = textView.layoutManager.characterIndexForPoint(dragEndLocation, inTextContainer: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
    let replacedCharacterRange = (textStorage.string as NSString).paragraphRangeForRange(NSRange(location: characterIndexUnderDrag, length: 1))
    let characterRange = replacedCharacterRange
    let replacedString = (textStorage.string as NSString).substringWithRange(characterRange)
    var replacingString = (textStorage.string as NSString).substringWithRange(draggedCharacterRange)
    if !(draggedCharacterRange.location == characterRange.location) {
      var replacedLineIndentation = indentationLevelOfLine(lineNumberForDraggedCharacterRange(characterRange))
      //let draggedLineIndentation = indentationLevelOfLine(lineNumberForDraggedCharacterRange(draggedCharacterRange))
      let trimmedString = replacedString.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
      if trimmedString.characters.count > 0 && trimmedString.substringFromIndex(trimmedString.endIndex.predecessor()) == ":"
        && !trimmedString.hasPrefix("loop:") {
          replacedLineIndentation++
      }
      //Make it so that if string wasn't indented before and was dragged into indentation zone,
      //it gets indented.
      replacingString = reindentString(replacingString, indentationLevel: replacedLineIndentation)
      textStorage.beginEditing()
      //edit the latter range first
      let replacingRange = NSRange(location: characterRange.location, length: 0)
      if draggedCharacterRange.location > characterRange.location {
        textStorage.replaceCharactersInRange(draggedCharacterRange, withString: "")
        textStorage.replaceCharactersInRange(replacingRange, withString: replacingString)
      } else {
        textStorage.replaceCharactersInRange(characterRange, withString: replacedString + replacingString)
        textStorage.replaceCharactersInRange(draggedCharacterRange, withString: "")
      }
      textStorage.endEditing()
      textView.setNeedsDisplay()
    } else {
      textStorage.beginEditing()
      textStorage.highlightSyntax()
      textStorage.endEditing()
      textView.setNeedsDisplay()
    }
  }
  
  private func reindentString(str:String, indentationLevel:Int) -> String {
    let strippedString = str.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
    switch LevelSettingsManager.sharedInstance.language {
    case .Python:
      return String(count: 4 * indentationLevel, repeatedValue: " " as Character) + strippedString
    default:
      print("WILL NOT REINDENT STRING FOR UNRECOGNIZED LANGUAGE")
      return str
    }
  }
  
  private func lineNumberForDraggedCharacterRange(range:NSRange) -> Int {
    let sourceString = (textStorage.string as NSString).substringWithRange(NSRange(location: 0, length: range.location))
    let errorPointer = NSErrorPointer()
    let regex: NSRegularExpression?
    do {
      regex = try NSRegularExpression(pattern: "\\n", options:[])
    } catch let error as NSError {
      errorPointer.memory = error
      regex = nil
    }
    let matches = regex!.numberOfMatchesInString(sourceString, options: [], range: NSRange(location: 0, length: sourceString.characters.count))
    return matches + 1
  }
  
  func scrollWhileDraggingIfNecessary(locationInParentView:CGPoint, yDelta:CGFloat) {
    let pvc = parentViewController as! PlayViewController
    let bounds = pvc.view.bounds
    var scrollOffset = pvc.scrollView.contentOffset
    var yOffset:CGFloat = 0
    let speed:CGFloat = 10
    //yDelta greater than zero means user is moving drag downwards
    if (locationInParentView.y > bounds.size.height * 0.8) && (yDelta > 0) {
      yOffset = speed * locationInParentView.y / bounds.size.height
    } else if (locationInParentView.y < bounds.size.height * 0.3) && (yDelta < 0) {
      yOffset = -1 * speed * (1.0 - locationInParentView.y / bounds.size.height)
    }
    if (yOffset < 0) {
      if scrollOffset.y == 0 || scrollOffset.y == pvc.scrollView.contentSize.height {
        return
      }
      if yOffset < -1 * scrollOffset.y {
        yOffset = -1 * scrollOffset.y
      }
    }
    scrollOffset.y += yOffset
    let rect = CGRect(x: 0, y: scrollOffset.y, width: pvc.scrollView.bounds.size.width, height: pvc.scrollView.bounds.size.height)
    pvc.scrollView.scrollRectToVisible(rect, animated: false)
  }
  
  func scrollViewDidScroll(scrollView: UIScrollView) {
    print("Scroll view did scroll!")
    textView.setNeedsDisplay()
  }
  
  
  func textViewDidChange(textView: UITextView) {
    textView.setNeedsDisplay()
  }
  
  
  
  func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
    if gestureRecognizer == tapGestureRecognizer {
      if textView.pointIsInLineNumberGutter(gestureRecognizer.locationInView(textView)) {
        print("Recieved tap!")
        return false
      }
      return true
    } else {
      if draggedLabel != nil {
        return false
      }
      //find if the nearest glyph is a newline (aka not dragging on a thing)
      let nearestGlyphIndexToDrag = textView.layoutManager.glyphIndexForPoint(gestureRecognizer.locationInView(textView), inTextContainer: textContainer)
      let characterIndex = textView.layoutManager.characterIndexForGlyphAtIndex(nearestGlyphIndexToDrag)
      let character = (textStorage.string as NSString).characterAtIndex(characterIndex)
      if character == 10 {
        return false
      }
      return true
    }
  }
  
  func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    return true
  }
  
  func createTextViewWithFrame(frame:CGRect) {
    setupTextKitHierarchy()
    textView = EditorTextView(frame: frame, textContainer: textContainer)
    textView.delegate = self
    textView.parentTextViewController = self
    textView.addGestureRecognizer(dragGestureRecognizer)
    textView.addGestureRecognizer(tapGestureRecognizer)
    textView.panGestureRecognizer.requireGestureRecognizerToFail(tapGestureRecognizer)
    textView.panGestureRecognizer.requireGestureRecognizerToFail(dragGestureRecognizer)
    view.addSubview(textView)
  }
  
  private func setupTextKitHierarchy() {
    let layoutManager = NSLayoutManager()
    layoutManager.allowsNonContiguousLayout = true
    textStorage.addLayoutManager(layoutManager)
    textContainer.lineBreakMode = NSLineBreakMode.ByWordWrapping
    textContainer.widthTracksTextView = true
    layoutManager.addTextContainer(textContainer)
  }
  
  func replaceTextViewContentsWithString(text:String) {
    textStorage.replaceCharactersInRange(NSRange(location: 0, length: textStorage.string.characters.count), withString: text)
    textView.setNeedsDisplay()
  }
  
  func textView(textView: UITextView, shouldChangeTextInRange range: NSRange, replacementText text: String) -> Bool {
    if text == "\n" {
      textView.setNeedsDisplay()
    }
    return true
  }
  
  
  
}
