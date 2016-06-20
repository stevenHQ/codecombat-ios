//
//  DocumentParser.swift
//  CodeCombat
//
//  Created by Michael Schmatz on 8/27/14.
//  Copyright (c) 2014 CodeCombat. All rights reserved.
//

import Foundation

//I'm going to provide proper attribution later, but most of this code is 
//translated directly from LimeText


func rangeCoversRange(a:NSRange, b:NSRange) -> Bool {
  let union = NSUnionRange(a, b)
  return union.location == a.location && union.length == a.length
}
class NodeHighlighter {
  var rootNode:DocumentNode!
  var lastScopeNode:DocumentNode!
  var lastScopeName:String = ""
  var lastScopeBuf:NSMutableString = ""
  var parser:LanguageParser
  init(parser:LanguageParser) {
    self.parser = parser
    rootNode = parser.parse()
  }
  
  func reparse() {
    lastScopeName = ""
    lastScopeBuf = ""
    lastScopeNode = nil
    rootNode = parser.parse()
  }
  // Given a text region, returns the innermost node covering that region.
  // Side-effects: Writes to nh.lastScopeBuf...
  func findScope(searchRange:NSRange, node:DocumentNode!) -> DocumentNode! {
    var idx = 0
    //TODO:Optimize through binary search
    for i in 0 ..< node.children.count {
      if node.children[i].range.location >= searchRange.location || rangeCoversRange(node.children[i].range,b: searchRange) {
        idx = i
        break
      }
    }
    while idx < node.children.count {
      let c = node.children[idx]
      if c.range.location > NSMaxRange(searchRange) {
        break
      }
      if rangeCoversRange(c.range, b: searchRange) {
        if node.name != nil && node.name != "" && lastScopeNode != nil && node !== lastScopeNode {
          if lastScopeBuf.length > 0 {
            lastScopeBuf.appendString(" ")
          }
          lastScopeBuf.appendString(node.name)
        }
        return findScope(searchRange, node: node.children[idx])
      }
      idx += 1
    }
    if node !== lastScopeNode && rangeCoversRange(node.range, b: searchRange) && node.name != nil && node.name != "" {
      if lastScopeBuf.length > 0 {
        lastScopeBuf.appendString(" ")
      }
      lastScopeBuf.appendString(node.name)
      return node
    }
    return nil
  }
  // Caches the full concatenated nested scope name and the innermost node that covers "point".
  func updateScope(point:Int) {
    if rootNode == nil {
      return
    }
    
    let search = NSRange(location: point, length: 1)
    if lastScopeNode != nil && rangeCoversRange(lastScopeNode.range, b: search) {
      if lastScopeNode.children.count != 0 {
        let no = findScope(search, node: lastScopeNode)
        if no != nil && no !== lastScopeNode {
          lastScopeNode = no
          lastScopeName = lastScopeBuf as String
        }
      }
      return
    }
    lastScopeNode = nil
    lastScopeBuf = ""
    lastScopeNode = findScope(search, node: rootNode)
    lastScopeName = lastScopeBuf as String
  }
  
  func scopeExtent(point:Int) -> NSRange? {
    updateScope(point)
    if lastScopeNode != nil {
      let range = lastScopeNode.range
      return range
    }
    return nil
  }
  
  func scopeName(point:Int) -> String {
    updateScope(point)
    return lastScopeName
  }
  
  
  func adjust(position:Int, delta:Int) {
    rootNode.adjust(position, delta: delta)
  }
  
}
class Regex {
  var regex:OnigRegexp!
  var lastIndex:Int = 0
  var lastFound:Int = 0
  
  init() {
    
  }
  func description() -> String {
    if regex == nil {
      return "nil"
    }
    return "\(regex.expression())  // \(lastIndex), \(lastFound)"
  }
  
  func find(data:NSString, pos:Int) -> OnigResult? {
    //the first few lines of this code effectively do nothing, refactor
    if lastIndex > pos {
      lastFound = 0
    }
    lastIndex = pos
    let result = regex.search(data as String, start: Int32(pos))
    return result
  }
}

//The language provider is responsible for parsing files into languages
class LanguageProvider {
  var scope:[String:String] = Dictionary<String,String>()
  var cachedLanguages:[String:Language?] = [:]
  func getLanguage(id:String) -> Language? {
    if let lang = cachedLanguages[id] {
      return lang
    }
    if let lang = languageFromScope(id) {
      lang.tweak()
      cachedLanguages[id] = lang
      return lang
    } else {
      let lang = languageFromFile(id)
      lang?.tweak()
      cachedLanguages[id] = lang
      return lang
    }
  }
  
  
  func languageFromScope(id:String) -> Language? {
    let fileName = scope[id]
    if fileName != nil {
      return languageFromFile(fileName!)
    } else {
      return nil
    }
  }
  
  func languageFromFile(languageFileName:String) -> Language? {
    //TODO: Verify that this doesn't screw up the app, I changed it from mainBundle for test compatibility
    let languageFilePath = NSBundle(forClass: LanguageProvider.self).pathForResource(languageFileName, ofType: "tmLanguageJSON")
    if languageFilePath == nil {
      return nil
    }
    let error:NSErrorPointer = nil
    let languageFileContents: NSString?
    do {
      languageFileContents = try NSString(contentsOfFile: languageFilePath!, encoding: NSUTF8StringEncoding)
    } catch let error1 as NSError {
      error.memory = error1
      languageFileContents = nil
    }
    if error != nil || languageFileContents == nil {
      return nil
    }
    
    let languageFileJSON = JSON.parse(languageFileContents! as String)
    let parsedLanguage = parseLanguageFileJSON(languageFileJSON)
    if parsedLanguage != nil {
      scope[parsedLanguage!.scopeName] = languageFileName
    }
    return parsedLanguage
  }
  
  private func parseLanguageFileJSON(data:JSON) -> Language? {
    let lang = Language()
    if let fileTypesArray = data["fileTypes"].asArray {
      for fileType in fileTypesArray {
        lang.fileTypes.append(fileType.asString!)
      }
    }
    lang.firstLineMatch = data["firstLineMatch"].asString
    lang.scopeName = data["scopeName"].asString!
    if let repository = data["repository"].asDictionary {
      for (patternName, pattern) in repository {
        lang.repository[patternName] = parsePattern(pattern)
      }
    }
    
    if let patterns = data["patterns"].asArray {
      //parse the root pattern here
      let rootPattern = Pattern()
      for pattern in patterns {
        rootPattern.patterns.append(parsePattern(pattern))
      }
      lang.rootPattern = rootPattern
    }
    return lang
  }
  
  private func parsePattern(data:JSON) -> Pattern {
    let pattern = Pattern()
    let patternName = data["name"].asString
    pattern.name = patternName != nil ? patternName : data["contentName"].asString
    pattern.contentName = data["contentName"].asString
    pattern.disabled = data["disabled"].asBool
    pattern.include = data["include"].asString
    if let matchData = data["match"].asString {
      let match = Regex()
      //TODO: Profile that compiling all of the regexes on the fly is performant
      match.regex = OnigRegexp.compile(matchData)
      pattern.match = match
    }
    if let captures = data["captures"].asDictionary {
      for (captureNumber, captureData) in captures {
        let capture = Capture(key: Int(captureNumber)!)
        capture.name = captureData["name"].asString
        pattern.captures.append(capture)
      }
      pattern.captures = pattern.captures.sort({$0.key < $1.key })
    }
    if let beginData = data["begin"].asString {
      let begin = Regex()
      begin.regex = OnigRegexp.compile(beginData)
      pattern.begin = begin
    }
    if let beginCaptures = data["beginCaptures"].asDictionary {
      for (captureNumber, captureData) in beginCaptures {
        let capture = Capture(key: Int(captureNumber)!)
        capture.name = captureData["name"].asString
        pattern.beginCaptures.append(capture)
      }
      pattern.beginCaptures = pattern.beginCaptures.sort({$0.key < $1.key })
    }
    if let endData = data["end"].asString {
      let end = Regex()
      end.regex = OnigRegexp.compile(endData)
      pattern.end = end
    }
    if let endCaptures = data["endCaptures"].asDictionary {
      for (captureNumber, captureData) in endCaptures {
        let capture = Capture(key: Int(captureNumber)!)
        capture.name = captureData["name"].asString
        pattern.endCaptures.append(capture)
      }
      pattern.endCaptures = pattern.endCaptures.sort({$0.key < $1.key })
    }
    if let patterns = data["patterns"].asArray {
      for patternData in patterns {
        let nestedPattern = parsePattern(patternData)
        pattern.patterns.append(nestedPattern)
      }
    }
    return pattern
  }
}

class Language {
  var fileTypes:[String] = []
  var firstLineMatch:String!
  var rootPattern:Pattern!
  var repository:[String:Pattern] = Dictionary<String,Pattern>()
  var scopeName:String = ""
  
  func tweak() {
    rootPattern.tweak(self)
    for (_, pattern) in repository {
      pattern.tweak(self)
    }
  }
}

class LanguageParser {
  var language:Language!
  var data:NSString
  let maxIterations = 10000
  
  init(scope:String, data:NSString, provider:LanguageProvider) {
    let lang = provider.getLanguage(scope)
    self.data = data
    if lang != nil {
      language = lang
    }
  }
  
  func parse() -> DocumentNode! {
    if data.length == 0 {
      return DocumentNode()
    }
    let rootNode = DocumentNode()
    let sdata = data
    rootNode.sourceText = sdata
    rootNode.name = language.scopeName
    var iterations = maxIterations
    for var i = 0; i < sdata.length && iterations > 0; iterations -= 1 {
      var (pat, result) = language.rootPattern.cache(sdata, position: i)
      let newLineLocation = sdata.rangeOfCharacterFromSet(NSCharacterSet.newlineCharacterSet(), options: [], range: NSRange(location: i, length: sdata.length - i)).location
      if result == nil {
        break
      } else if newLineLocation != NSNotFound && newLineLocation <= Int(result!.locationAt(0)) {
        i = newLineLocation
        while i + 1 < sdata.length && (sdata.substringWithRange(NSRange(location: i, length: 1)) == "\n" || sdata.substringWithRange(NSRange(location: i, length: 1)) == "\r") {
          i += 1
        }
      } else {
        let n = pat!.createNode(sdata, pos: i, d: sdata, result: result!)
        rootNode.children.append(n)
        i = NSMaxRange(n.range)
      }
    }
    rootNode.updateRange()
    if sdata.length != 0 {
      var lut:[Int] = []
      var j = 0
      for _ in 0 ..< sdata.length {
        lut.append(j)
        j += 1
      }
      lut.append(data.length)
      self.patch(lut, node: rootNode)
    }
    if iterations == 0 {
      print("REACHED MAXIMUM NUMBER OF ITERATIONS")
      return nil
    }
    rootNode.simplify()
    return rootNode
  }
  
  func patch(lut:[Int], node:DocumentNode) {
    node.range.location = lut[node.range.location]
    node.range.length = lut[NSMaxRange(node.range)] - node.range.location
    for child in node.children {
      self.patch(lut, node: child)
    }
  }
}

class Capture {
  var key:Int
  var name:String!
  init(key:Int) {
    self.key = key
  }
}

class Pattern {
  //change the implicitly unwrapped optionals once construction is understood
  var name:String!
  var contentName:String!
  var disabled:Bool! = false
  var include:String!
  var match:Regex!
  var captures:[Capture] = []
  var begin:Regex!
  var beginCaptures:[Capture] = []
  var end:Regex!
  var endCaptures:[Capture] = []
  var patterns:[Pattern] = []
  var owner:Language!
  var cachedData:NSString!
  var cachedPattern:Pattern!
  var cachedPatterns:[Pattern] = []
  var cachedMatch:OnigResult!
  var hits:Int = 0
  var misses:Int = 0
  
  func description() -> String {
    var desc = "---------------------------------------\n"
    desc += "Name:    \(name)\n"
    desc += "Match:   \(match?.description())\n"
    desc += "Begin:   \(begin?.description())\n"
    desc += "BeginCaptures \(beginCaptures)\n"
    desc += "End:     \(end?.description())\n"
    desc += "EndCaptures: \(endCaptures)\n"
    desc += "Include: \(include)\n"
    desc += "<Sub-Patterns>\n"
    for pat in patterns {
      var inner = pat.description()
      inner = inner.stringByReplacingOccurrencesOfString("\t", withString: "\t\t", options: [], range: nil)
      inner = inner.stringByReplacingOccurrencesOfString("\n", withString: "\n\t", options: [], range: nil)
      desc +=  "\t\(inner)\n"
    }
    desc += "</Sub-Patterns>\n---------------------------------------"
    return desc
  }
  func tweak(l:Language) {
    owner = l
    name = name?.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
    for pattern in patterns {
      pattern.tweak(l)
    }
  }
  
  func cache(data:NSString, position:Int) -> (pat:Pattern?, result:OnigResult?) {
    if cachedData === data {
      if cachedMatch == nil {
        return (nil,nil)
      }
      if cachedMatch.bodyRange().location >= position && cachedPattern.cachedPattern != nil {
        hits += 1
        return (cachedPattern, cachedMatch)
      }
    } else {
      cachedPatterns = []
    }
    if cachedPatterns.count == 0 {
      for pattern in patterns {
        cachedPatterns.append(pattern)
      }
    } 
    misses += 1
    var pat:Pattern? = nil
    var result:OnigResult?
    if match?.regex != nil {
      pat = self
      //println("Searching \(data) from position \(position)")
      //println("Regex is \(match.regex.expression())")
      result = match.find(data, pos: position)
      if result != nil {
        //println(result!.body())
      }
      
    } else if begin?.regex != nil {
      pat = self
      result = begin.find(data, pos: position)
    } else if include != nil {
      let includePrefix = Array(include.characters)[0]
      if includePrefix == "#" {
        let key = include.substringFromIndex(include.startIndex.successor())
        let includePattern = owner.repository[key]
        if includePattern != nil {
          (pat, result) = includePattern!.cache(data, position: position)
        } else {
          print("The pattern \(key) wasn't found!")
        }
      } else if includePrefix == "$" {
        if include == "$self" {
          (pat, result) = owner.rootPattern.cache(data, position: position)
        }
        //Also handle alternative languages
      }
    } else {
      (pat, result) = firstMatch(data, pos: position)
    }
    cachedData = data
    cachedMatch = result
    cachedPattern = pat
    return (pat, result)
  }
  
  func firstMatch(data:NSString, pos:Int) -> (pat:Pattern?, ret:OnigResult?) {
    var startIndex = -1
    var pat:Pattern? = nil
    var ret:OnigResult? = nil
    for var i=0; i < cachedPatterns.count; {
      let (ip, im) = cachedPatterns[i].cache(data, position: pos)
      //println("Trying to find match from position \(pos) for data \(data) using pattern \(ip?.name), found one at \(im?.bodyRange().location)")
      if im != nil {
        if startIndex < 0 || startIndex > im!.bodyRange().location {
          startIndex = im!.bodyRange().location
          pat = ip
          ret = im
          if im!.bodyRange().location == pos {
            break
          }
        }
        i += 1
      } else {
        //pop the cached pattern
        cachedPatterns.removeAtIndex(i)
      }
    }
    return (pat, ret)
  }
  
  func createCaptureNodes(data:NSString, pos:Int, d:NSString, result:OnigResult, parent:DocumentNode, capt:[Capture]) {
    //I think the captures are probably unnecessary and can be refactored out
    //This function needs a lot of work
    //create a node per match result
    if capt.count > 0 {
      for var capNumber = 1; UInt(capNumber) < result.count(); capNumber += 1 {
        if result.stringAt(UInt(capNumber)) == "" {
          continue
        }
        //println(result.stringAt(UInt(capNumber)))
        //println("Capture \(capNumber)")
        _ = result.rangeAt(UInt(capNumber))
        //println("Range: Location:\(capRange.location), length: \(capRange.length)")
        let child = DocumentNode()
        var cap:Capture! = nil
        for capture in capt {
          if capture.key == capNumber {
            cap = capture
            break
          }
        }
        if cap == nil {
          cap = capt[capNumber]
        }
        child.name = cap.name
        child.range = result.rangeAt(UInt(capNumber))
        child.sourceText = data
        child.parent = parent
        parent.children.append(child)
      }
      return
    }
  }
  
  func createNode(data:NSString, pos:Int, d:NSString, result:OnigResult) -> DocumentNode {
    let createdNode = DocumentNode()
    //println("Creating node for pattern \(name), include \(include)")
    createdNode.name = name
    createdNode.range = result.rangeAt(0)
    createdNode.sourceText = data
    //println(match)
    //println(match == nil)
    //createdNode.updateRange() MUST be deferred
    //TODO: Need to fix contentName
    if match != nil && match!.regex != nil {
      createCaptureNodes(data, pos: pos, d: d, result: result, parent: createdNode, capt: captures)
    }
    if begin == nil || begin.regex == nil {
      createdNode.updateRange()
      return createdNode
    }
    if beginCaptures.count > 0 {
      createCaptureNodes(data, pos: pos, d: d, result: result, parent: createdNode, capt: beginCaptures)
    } else {
      createCaptureNodes(data, pos: pos, d: d, result: result, parent: createdNode, capt: captures)
    }
    if self.end == nil || self.end.regex == nil {
      createdNode.updateRange()
      return createdNode
    }
    var found = false
    var i = NSMaxRange(createdNode.range)
    var end = data.length
    while i < data.length {
      let endMatch = self.end.find(data, pos: i)
      
      //println(endMatch)
      //println("WOOO")
      if endMatch != nil {
        end = NSMaxRange(endMatch!.rangeAt(0))
      } else {
        if !found {
          //no end found, set to next line
          let substringToSearch = NSString(string:data.substringFromIndex(i))
          let newlineLocation = substringToSearch.rangeOfCharacterFromSet(NSCharacterSet.newlineCharacterSet()).location
          if newlineLocation != NSNotFound {
            end = i + newlineLocation
          } else {
            end = data.length
          }
        } else {
          end = i
        }
        break
      }
      if cachedPatterns.count > 0 {
        let (pattern2, result2) = firstMatch(data, pos: i)
        if result2 != nil && ((endMatch == nil && result2!.locationAt(0) < UInt(end)) || (endMatch != nil && (result2!.locationAt(0) < endMatch!.locationAt(0) || result2!.locationAt(0) == endMatch!.locationAt(0) && createdNode.range.length == 0))) {
          found = true
          let r = pattern2?.createNode(data, pos: i, d: d, result: result2!)
          createdNode.children.append(r!)
          i = NSMaxRange(r!.range)
          continue
        }
      }
      if endMatch != nil {
        if endCaptures.count > 0 {
          createCaptureNodes(data, pos: i, d: d, result: endMatch!, parent: createdNode, capt: endCaptures)
        } else {
          createCaptureNodes(data, pos: i, d: d, result: endMatch!, parent: createdNode, capt: captures)
        }
      }
      break
    }
    createdNode.range.length = end - createdNode.range.location
    createdNode.updateRange()
    return createdNode
  }
}
