import XCTest
import UIKit
final class TabCapture: XCTestCase {
 let app=XCUIApplication(bundleIdentifier:"com.larry.keepfit")
 func testTabsOnly() throws {
  let config=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:"/tmp/keepfit-tab-capture-config.json")))as![String:String]
  let group=config["group"]!,root=URL(fileURLWithPath:config["output"]!),screenIndex=Int(config["screenIndex"]!)!
  if !group.hasPrefix("duo") || group=="duo-outer"{XCUIDevice.shared.orientation = .portrait}
  for lang in ["zh-Hans","en"] {
   app.launchArguments=["-keepfit-screenshot-mode","-keepfit-screenshot-date","2026-10-27","-keepfit-selected-tab","eat","-keepfit-screenshot-language",lang,"-AppleLanguages",lang=="en" ? "(en)":"(zh-Hans)","-AppleLocale",lang=="en" ? "en_US":"zh_CN"]
   app.launch();XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout:20));Thread.sleep(forTimeInterval:2)
   let d=root.appendingPathComponent("05_Sources/recordings").appendingPathComponent(group).appendingPathComponent(lang)
   let shots=root.appendingPathComponent("05_Sources/screens").appendingPathComponent(group).appendingPathComponent(lang)
   try FileManager.default.createDirectory(at:d,withIntermediateDirectories:true);try FileManager.default.createDirectory(at:shots,withIntermediateDirectories:true)
   try Data().write(to:d.appendingPathComponent("ready"))
   for _ in 0..<500{if FileManager.default.fileExists(atPath:d.appendingPathComponent("ack").path){break};Thread.sleep(forTimeInterval:0.1)}
   var timeline:[[String:Any]]=[]
   for(index,tab)in["eat","move","lose"].enumerated(){
    let start=Date().timeIntervalSince1970
    if index>0 {
     let label=tab=="move" ? (lang=="en" ? "Move More":"迈开腿"):(lang=="en" ? "Lose Weight":"减个肥")
     let nav=app.descendants(matching:.any).matching(NSPredicate(format:"label == %@",label)).firstMatch
     XCTAssertTrue(nav.waitForExistence(timeout:10));nav.tap()
    }
    Thread.sleep(forTimeInterval:1)
    let key=tab=="eat" ? "eat":tab=="move" ? "move":"lose"
    let screen=XCUIScreen.screens[min(screenIndex,XCUIScreen.screens.count-1)]
    try screen.screenshot().pngRepresentation.write(to:shots.appendingPathComponent(key+"-overview.png"))
    let pane=app.scrollViews["keepfit.records"].exists ? app.scrollViews["keepfit.records"]:app.scrollViews["keepfit.singleColumn"]
    XCTAssertTrue(pane.exists);pane.swipeUp(velocity:.slow)
    if tab=="lose" || (tab=="eat" && group=="duo-outer"){pane.swipeUp(velocity:.slow)}
    Thread.sleep(forTimeInterval:0.8)
    try screen.screenshot().pngRepresentation.write(to:shots.appendingPathComponent(key+"-details.png"))
    pane.swipeDown(velocity:.slow)
    if tab=="lose" || (tab=="eat" && group=="duo-outer"){pane.swipeDown(velocity:.slow)}
    Thread.sleep(forTimeInterval:0.8)
    timeline.append(["tab":tab,"start":start,"end":Date().timeIntervalSince1970])
   }
   try JSONSerialization.data(withJSONObject:timeline,options:.prettyPrinted).write(to:d.appendingPathComponent("timeline.json"))
   try Data().write(to:d.appendingPathComponent("done"));app.terminate()
  }
 }
}
