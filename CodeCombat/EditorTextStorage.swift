//
//  editorTextStorage.swift
//  iPadClient
//
//  Created by Michael Schmatz on 7/28/14.
//  Copyright (c) 2014 CodeCombat. All rights reserved.
//

import UIKit

//Thank you http://www.objc.io/issue-5/getting-to-know-textkit.html

class EditorTextStorage: NSTextStorage {
  var attributedStringStore:NSMutableAttributedString
  var languageProvider = LanguageProvider()
  var highlighter:NodeHighlighter!
  let language = "python"
  let undoManager = NSUndoManager()
  var nestedEditingLevel = 0
  var makingTextClear = false
  
  override init() {
    attributedStringStore = NSMutableAttributedString()
    super.init()
    let parser = LanguageParser(scope: language, data: attributedStringStore.string, provider: languageProvider)
    highlighter = NodeHighlighter(parser: parser)
  }
  
  required init?(coder aDecoder: NSCoder) {
    attributedStringStore = NSMutableAttributedString()
    super.init(coder: aDecoder)
    let parser = LanguageParser(scope: language, data: attributedStringStore.string, provider: languageProvider)
    highlighter = NodeHighlighter(parser: parser)
  }
  
  override var string: String {
    return attributedStringStore.string
  }
  
  override func beginEditing() {
    nestedEditingLevel += 1
    super.beginEditing()
  }
  override func endEditing() {
    super.endEditing()
    //If you need to do things which require laying out glyphs, do them here. If you trigger them
    //before, you'll crash.
    //Not counting clearing text as an edit per se, we shouldn't highlight if just doing that
    if nestedEditingLevel == 1 && !makingTextClear {
      NSNotificationCenter.defaultCenter().postNotificationName("textStorageFinishedTopLevelEditing", object: nil)
      highlightSyntax()
    }
    nestedEditingLevel -= 1
  }
  
  func characterIsPartOfString(characterIndex:Int) -> Bool {
    _ = highlighter.scopeName(characterIndex)
    let node = highlighter.lastScopeNode
    if node == nil {
      return false
    }
    return node.name.hasPrefix("string")
  }
  
  //caller is responsible for checking if character is part of string
  func stringRangeContainingCharacterIndex(characterIndex:Int) -> NSRange {
    _ = highlighter.scopeName(characterIndex)
    let node = highlighter.lastScopeNode
    return node.range
  }
  
  func characterIsPartOfNumber(characterIndex:Int) -> Bool {
    _ = highlighter.scopeName(characterIndex)
    let node = highlighter.lastScopeNode
    if node == nil {
      return false
    }
    return node.name.hasPrefix("constant.numeric")
  }
  
  func findArgumentOverlays() -> [(String,NSRange)] {
    var argumentOverlays:[(String,NSRange)] = []
    let documentRange = NSRange(location: 0, length: string.characters.count)
    for var charIndex = documentRange.location; charIndex < NSMaxRange(documentRange); charIndex += 1 {
      let scopeName = highlighter.scopeName(charIndex)
      let scopes = scopeName.componentsSeparatedByString(" ")
      for scope in scopes {
        let scopeExtent = highlighter.scopeExtent(charIndex)
        if scopeExtent == nil {
          continue
        }
        //Identify the function name here
        if scope.hasPrefix("codecombat.arguments") {
          //go past the ( and into the function name
          _ = highlighter.scopeName(charIndex - 2)
          var functionName = "unsetForLanguage\(language)"
          if language == "python" {
            let parentNode = highlighter.lastScopeNode
            if parentNode != nil {
              if parentNode.name == nil || !parentNode.name.hasPrefix("meta.function-call") {
                functionName = ""
              } else {
                functionName = parentNode.data
              }
            }
          }
          let argumentOverlayTuple = (functionName, scopeExtent!)
          argumentOverlays.append(argumentOverlayTuple)
          charIndex = NSMaxRange(scopeExtent!)
        }
      }
    }
    return argumentOverlays
  }
  
  func getDefinedVariableNames() -> [String] {
    var definedVariables:[String] = []
    //DFS, optimize later
    var stack:[DocumentNode] = []
    let rootNode = highlighter.rootNode
    stack.append(rootNode)
    while stack.count > 0 {
      let node = stack.last!
      stack.removeLast()
      //This is such a hack
      if (node.name == nil || node.name == "") && node.data != "loop"{
        definedVariables.append(node.data)
      }
      for child in node.children {
        stack.append(child)
      }
    }
    definedVariables = removeDuplicatesFromArrayOfStrings(definedVariables)
    return definedVariables
  }
  
  func getDefinedVariableRanges() -> [NSRange] {
    var definedVariables:[NSRange] = []
    //DFS, optimize later
    var stack:[DocumentNode] = []
    let rootNode = highlighter.rootNode
    stack.append(rootNode)
    while stack.count > 0 {
      let node = stack.last!
      stack.removeLast()
      //This is such a hack
      if (node.name == nil || node.name == "") && node.data != "loop" {
        definedVariables.append(node.range)
      }
      for child in node.children {
        stack.append(child)
      }
    }
    return definedVariables
  }
  
  func characterIsPartOfDefinedVariable(characterIndex:Int) -> NSRange? {
    let definedVariableRanges = getDefinedVariableRanges()
    for range in definedVariableRanges {
      if characterIndex >= range.location && characterIndex < range.location + range.length {
        return range
      }
    }
    return nil
  }
  
  func removeDuplicatesFromArrayOfStrings(arr:[String]) -> [String] {
    var extantItems:[String] = []
    return arr.filter({
      if !extantItems.contains($0) {
        extantItems.append($0)
        return true
      } else {
        return false
      }
    })
    
  }
  
  func makeTextClear() {
    makingTextClear = true
    addAttribute(NSForegroundColorAttributeName, value: UIColor.clearColor(), range: NSRange(location: 0, length: string.characters.count))
    makingTextClear = false
  }
  
  func highlightSyntax() {
    let parser = LanguageParser(scope: language, data: attributedStringStore.string, provider: languageProvider)
    highlighter = NodeHighlighter(parser: parser)
    //the most inefficient way of doing this, optimize later
    let documentRange = NSRange(location: 0, length: string.characters.count)
    
    self.removeAttribute(NSForegroundColorAttributeName, range: documentRange)
    for var charIndex = documentRange.location; charIndex < NSMaxRange(documentRange); charIndex += 1 {
      let scopeName = highlighter.scopeName(charIndex)
      let scopes = scopeName.componentsSeparatedByString(" ")
      for scope in scopes {
        let scopeExtent = highlighter.scopeExtent(charIndex)
        if scopeExtent == nil {
          continue
        }
        if scope.hasPrefix("comment") {
          addAttribute(NSForegroundColorAttributeName, value: UIColor.grayColor(), range: scopeExtent!)
          charIndex = NSMaxRange(scopeExtent!)
        } else if scope.hasPrefix("meta.function-call.generic") { //function calls
          addAttribute(NSForegroundColorAttributeName, value: UIColor.redColor(), range: scopeExtent!)
          charIndex = NSMaxRange(scopeExtent!)
        } else if scope.hasPrefix("variable.language") && highlighter.lastScopeNode.data == "self" { //python self
          addAttribute(NSForegroundColorAttributeName, value: UIColor.purpleColor(), range: scopeExtent!)
          charIndex = NSMaxRange(scopeExtent!)
        }
      }
    }
    
  }
  
  override func attributesAtIndex(location: Int, effectiveRange range: NSRangePointer) -> [String : AnyObject] {
    let attributes = attributedStringStore.attributesAtIndex(location, effectiveRange: range)
    return attributes
  }
  
  override func replaceCharactersInRange(range: NSRange, withString str: String) {
    let previousContents = attributedStringStore.attributedSubstringFromRange(range)
    var newRange = range
    newRange.length = NSString(string: str).length
    undoManager.prepareWithInvocationTarget(self).replaceCharactersInRange(newRange, withAttributedString: previousContents)
    beginEditing()
    attributedStringStore.replaceCharactersInRange(range, withString: str)
    let changeInLength:NSInteger = (NSString(string: str).length - range.length)
    self.edited(NSTextStorageEditActions.EditedCharacters,
      range: range,
      changeInLength: changeInLength)
    endEditing()
  }
  
  override func replaceCharactersInRange(range: NSRange, withAttributedString attrString: NSAttributedString) {
    let previousContents = attributedStringStore.attributedSubstringFromRange(range)
    var newRange = range
    newRange.length = NSString(string: attrString.string).length
    undoManager.prepareWithInvocationTarget(self).replaceCharactersInRange(newRange, withAttributedString: previousContents)
    beginEditing()
    attributedStringStore.replaceCharactersInRange(range, withAttributedString: attrString)
    let changeInLength:NSInteger = (NSString(string: attrString.string).length - range.length)
    self.edited(NSTextStorageEditActions.EditedCharacters,
      range: range,
      changeInLength: changeInLength)
    endEditing()
  }
  
  override func processEditing() {
    super.processEditing()
    NSNotificationCenter.defaultCenter().postNotificationName("textEdited", object: nil)
  }
  
  
  override func setAttributes(attrs: [String : AnyObject]!, range: NSRange) {
    attributedStringStore.setAttributes(attrs, range: range)
    self.edited(NSTextStorageEditActions.EditedAttributes,
      range: range,
      changeInLength: 0)
  }
}
