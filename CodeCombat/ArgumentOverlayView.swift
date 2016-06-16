//
//  ArgumentOverlayView.swift
//  CodeCombat
//
//  Created by Michael Schmatz on 10/28/14.
//  Copyright (c) 2014 CodeCombat. All rights reserved.
//

import Foundation

class ArgumentOverlayView: UIButton, StringPickerPopoverDelegate {
  var characterRange:NSRange! //represents the character range this view is over
  var editorTextViewController:EditorTextViewController!
  var functionName = ""
  var defaultContentsToInsertOnRun = ""
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
  
  init(frame: CGRect, textViewController:EditorTextViewController, characterRange:NSRange, functionName:String) {
    super.init(frame: frame)
    
    editorTextViewController = textViewController
    self.characterRange = characterRange
    self.functionName = functionName
    
    customizeViewAppearance()
    setupDefaultLabel()
    resetLocationToCurrentCharacterRange()
    
    addTarget(self, action: #selector(ArgumentOverlayView.onTapped), forControlEvents: .TouchUpInside)
    NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ArgumentOverlayView.onCodeRun), name: "codeRun", object: nil)
    NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ArgumentOverlayView.onOverlayHideRequest), name: "overlayHideRequest", object: nil)
    NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ArgumentOverlayView.onOverlayUnhideRequest), name: "overlayUnhideRequest", object: nil)
    
  }
  
  func onOverlayHideRequest() {
    hidden = true
  }
  
  func onOverlayUnhideRequest() {
    hidden = false
  }
  
  deinit {
    NSNotificationCenter.defaultCenter().removeObserver(self)
  }
  
  func onTapped() {
    switch LevelSettingsManager.sharedInstance.level {
    case .TrueNames:
      makeStringChoicePopoverWithChoices(["\"Brak\"","\"Treg\""])
    case .FavorableOdds:
      makeStringChoicePopoverWithChoices(["\"Krug\"","\"Grump\""])
    case .TheRaisedSword:
      makeStringChoicePopoverWithChoices(["\"Gurt\"","\"Rig\"","\"Ack\""])
    case .DreadDoor:
      makeStringChoicePopoverWithChoices(["\"Door\""])
    case .KithgardGates:
      makeStringChoicePopoverWithChoices(["\"fence\""])
    default:
      var variables = editorTextViewController.textStorage.getDefinedVariableNames()
      let theIndex = editorTextViewController.textStorage.string.startIndex.advancedBy(characterRange.location)
      let substringBeforeOverlay = editorTextViewController.textStorage.string.substringToIndex(theIndex)
      variables = variables.filter({
        return substringBeforeOverlay.rangeOfString($0) != nil
      })
      if functionName != "attack" || variables.count == 0 {
        if !variables.contains(defaultContentsToInsertOnRun) {
          variables.append(defaultContentsToInsertOnRun)
        }
      }
      
      makeStringChoicePopoverWithChoices(variables)
    }
  }
  
  func onCodeRun() {
    stringWasSelectedByStringPickerPopover(defaultContentsToInsertOnRun, characterRange:characterRange)
  }
  
  internal func stringWasSelectedByStringPickerPopover(selected:String, characterRange:NSRange) {
    editorTextViewController.replaceCharactersInCharacterRange(characterRange, str: selected)
    self.hidden = true
  }
  
  private func customizeViewAppearance() {
    backgroundColor = UIColor.redColor()
    layer.cornerRadius = 10
    layer.masksToBounds = true
  }
  
  private func setupDefaultLabel() {
    switch LevelSettingsManager.sharedInstance.level {
    case .TrueNames:
      addSubview(makeDefaultLabelWithText("\"Brak\""))
    case .FavorableOdds:
      addSubview(makeDefaultLabelWithText("\"Krug\""))
    case .TheRaisedSword:
      addSubview(makeDefaultLabelWithText("\"Gurt\""))
    case .DreadDoor:
      addSubview(makeDefaultLabelWithText("\"Door\""))
    case .KithgardGates:
      addSubview(makeDefaultLabelWithText("\"fence\""))
    default:
      //get variables
      let variables = editorTextViewController.textStorage.getDefinedVariableNames()
      //enemy is the target variable, search for variables already defined
      var lowestFree = 0
      if variables.contains("enemy") {
        lowestFree = 2
      }
      for variable in variables {
        if variable.hasPrefix("enemy") {
          let restOfString = variable.stringByReplacingOccurrencesOfString("enemy", withString: "", options: [], range: nil)
          let numericString = restOfString.stringByTrimmingCharactersInSet(NSCharacterSet.letterCharacterSet())
          if let number = Int(numericString) {
            if number >= lowestFree {
              lowestFree = number + 1
            }
          }
        }
      }
      var placeholder = "enemy"
      if lowestFree != 0 && functionName != "attack" {
        placeholder += String(lowestFree)
      }
      addSubview(makeDefaultLabelWithText(placeholder))
    }
  }
  
  private func makeStringChoicePopoverWithChoices(choices:[String]) {
    editorTextViewController.createStringPickerPopoverWithChoices(choices,
      characterRange: characterRange,
      delegate: self)
  }
  
  private func resetLocationToCurrentCharacterRange() {
    let glyphRange = editorTextViewController.textView.layoutManager.glyphRangeForCharacterRange(characterRange, actualCharacterRange: nil)
    var boundingRect = editorTextViewController.textView.layoutManager.boundingRectForGlyphRange(glyphRange, inTextContainer: editorTextViewController.textContainer)
    boundingRect.origin.y += editorTextViewController.textView.lineSpacing
    frame = boundingRect
    setNeedsDisplay()
  }
  
  private func makeDefaultLabelWithText(text:String) -> UILabel {
    let defaultLabel = UILabel(frame: CGRect(x: 0, y: editorTextViewController.textView.lineSpacing, width: 0, height: 0))
    defaultLabel.text = text
    defaultLabel.font = editorTextViewController.textView.font
    defaultLabel.sizeToFit()
    defaultContentsToInsertOnRun = text
    return defaultLabel
  }
}
