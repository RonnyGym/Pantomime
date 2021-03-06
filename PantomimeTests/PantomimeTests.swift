//
//  PantomimeTests.swift
//  PantomimeTests
//
//  Created by Thomas Christensen on 24/08/16.
//  Copyright © 2016 Nordija A/S. All rights reserved.
//

import XCTest
@testable import Pantomime

class PantomimeTests: XCTestCase {
  func testParseMediaPlaylist() {
    let bundle = Bundle(for: type(of: self))
    let path = bundle.path(forResource: "media_v", ofType: "m3u8")!
    
    let manifestBuilder = ManifestBuilder()
    let mediaPlaylist = manifestBuilder.parseMediaPlaylistFromFile(path, onMediaSegment: { (segment: MediaSegment) -> Void in
      XCTAssertNotNil(segment.sequence)
    })
    
    XCTAssert(mediaPlaylist.targetDuration == 11)
    XCTAssert(mediaPlaylist.mediaSequence == 0)
    XCTAssert(mediaPlaylist.segments.count == 123)
    XCTAssert(mediaPlaylist.segments[0].title == "")
    XCTAssert(mediaPlaylist.segments[0].subrangeLength == 876456)
    XCTAssert(mediaPlaylist.segments[0].subrangeStart == 0)
    XCTAssert(mediaPlaylist.segments[1].subrangeLength == 1358864)
    XCTAssert(mediaPlaylist.segments[1].subrangeStart == 876456)
    XCTAssert(mediaPlaylist.segments[2].duration == 10.8)
    XCTAssert(mediaPlaylist.segments[2].path! == "1540306021904-huwfw1.ts")
    XCTAssert(mediaPlaylist.duration() == 1328.0405)
    
    if let path2 = bundle.path(forResource: "media_a", ofType: "m3u8") {
      let mediaPlaylist2 = manifestBuilder.parseMediaPlaylistFromFile(path2, onMediaSegment: { (segment: MediaSegment) -> Void in
        XCTAssertNotNil(segment.sequence)
      })
      
      XCTAssertEqual(11, mediaPlaylist2.targetDuration, "Should have been read as 11 seconds")
    }
  }
  
  func testParseMasterPlaylist() {
    let bundle = Bundle(for: type(of: self))
    let path = bundle.path(forResource: "master", ofType: "m3u8")!
    let manifestBuilder = ManifestBuilder()
    let masterPlaylist = manifestBuilder.parseMasterPlaylistFromFile(path, onMediaPlaylist: { (playlist: MediaPlaylist) -> Void in
      XCTAssertNotNil(playlist.programId)
      XCTAssertNotNil(playlist.bandwidth)
      XCTAssertNotNil(playlist.path)
    })
    
    XCTAssert(masterPlaylist.playlists.count == 5)
  }
  
  /**
   * This would be the typical set up. Users will use Alomofire or similar libraries to
   * fetch the manifest files and then parse the text.
   */
  func testParseFromString() {
    let bundle = Bundle(for: type(of: self))
    let file = bundle.path(forResource: "master", ofType: "m3u8")!
    let path = URL(fileURLWithPath: file)
    
    do {
      let manifestText = try String(contentsOf: path, encoding: String.Encoding.utf8)
      let manifestBuilder = ManifestBuilder()
      let masterPlaylist = manifestBuilder.parseMasterPlaylistFromString(manifestText)
      XCTAssert(masterPlaylist.playlists.count == 5)
    } catch {
      XCTFail("Failed to read master playlist file")
    }
  }
  
  func testRealWorldParsing() {
    let manifestBuilder = ManifestBuilder()
    
    // Keep baseURL separate to contruct the nested media playlist URL's
    let baseURL = "http://devimages.apple.com/iphone/samples/bipbop"
    let path = "bipbopall.m3u8"
    let URL = Foundation.URL(string: baseURL + "/" + path)!
    XCTAssertEqual("http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8", URL.absoluteString)
    
    let expectation = self.expectation(description: "Testing parsing of the apple bipbop HTTP Live Stream sample")
    
    let session = URLSession.shared
    
    // Request master playlist
    let task = session.dataTask(with: URL, completionHandler: {
      data, response, error in
      
      XCTAssertNotNil(data, "data should not be nil")
      XCTAssertNil(error, "error should be nil")
      
      if let httpResponse = response as? HTTPURLResponse,
        let responseURL = httpResponse.url,
        let mimeType = httpResponse.mimeType {
        
        XCTAssertEqual(responseURL.absoluteString, URL.absoluteString, "No redirect expected")
        XCTAssertEqual(httpResponse.statusCode, 200, "HTTP response status code should be 200")
        XCTAssertEqual(mimeType, "audio/x-mpegurl", "HTTP response content type should be text/html")
        
        // Parse master playlist and perform verification of it
        if let dataFound = data, let manifestText = String(data: dataFound, encoding: String.Encoding.utf8) {
          
          let masterPlaylist = manifestBuilder.parseMasterPlaylistFromString(manifestText,
                                                                             onMediaPlaylist: {
                                                                              (mep: MediaPlaylist) -> Void in
                                                                              
                                                                              // Deduct full media playlist URL from path
                                                                              if let path = mep.path, let mepURL = Foundation.URL(string: baseURL + "/" + path) {
                                                                                
                                                                                // Request each found media playlist
                                                                                let mepTask = session.dataTask(with: mepURL, completionHandler: {
                                                                                  mepData, mepResponse, mepError in
                                                                                  
                                                                                  XCTAssertNotNil(mepData, "data should not be nil")
                                                                                  XCTAssertNil(mepError, "error should be nil")
                                                                                  
                                                                                  // Parse the media playlist and perform validation
                                                                                  if let mepDataFound = mepData,
                                                                                    let mepManifest = String(data: mepDataFound, encoding: String.Encoding.utf8) {
                                                                                    let mediaPlaylist = manifestBuilder.parseMediaPlaylistFromString(mepManifest)
                                                                                    XCTAssertEqual(181, mediaPlaylist.segments.count)
                                                                                  }
                                                                                  
                                                                                  // In case we have requested, parsed and validated the last one
                                                                                  if path.contains("gear4/prog_index.m3u8") {
                                                                                    expectation.fulfill()
                                                                                  }
                                                                                })
                                                                                
                                                                                mepTask.resume()
                                                                              }
          })
          
          XCTAssertEqual(4, masterPlaylist.playlists.count)
        }
      } else {
        XCTFail("Response was not NSHTTPURLResponse")
      }
    })
    
    task.resume()
    
    waitForExpectations(timeout: task.originalRequest!.timeoutInterval) {
      error in
      if let error = error {
        XCTFail("Error: \(error.localizedDescription)")
      }
      task.cancel()
    }
  }
  
  func testParsingJustUsingStringSource() {
    let builder = ManifestBuilder()
    
    // Check using String with contentsOfURL
    do {
      if let url = URL(string: "http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8") {
        let content = try String(contentsOf: url, encoding: String.Encoding.utf8)
        let master = builder.parseMasterPlaylistFromString(content)
        XCTAssertEqual(4, master.playlists.count, "Number of media playlists in master does not match")
      } else {
        XCTFail("Failed to create plain URL to bipbopall,m3u8")
      }
    } catch {
      XCTFail("Failed to just use string to read from various sources")
    }
  }
  
  func testSimpleFullParse() {
    let builder = ManifestBuilder()
    if let url = URL(string: "http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8") {
      let manifest = builder.parse(url)
      XCTAssertEqual(4, manifest.playlists.count)
    }
  }
  
  func testFullParse() {
    let builder = ManifestBuilder()
    if let url = URL(string: "http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8") {
      let manifest = builder.parse(url, onMediaPlaylist: {
        (media: MediaPlaylist) -> Void in
        XCTAssertNotNil(media.path)
      }, onMediaSegment: {
        (segment: MediaSegment) -> Void in
        let mediaManifestURL = url.URLByReplacingLastPathComponent(segment.mediaPlaylist!.path!)
        let segmentURL = mediaManifestURL!.URLByReplacingLastPathComponent(segment.path!)
        XCTAssertNotNil(segmentURL!.absoluteString)
      })
      XCTAssertEqual(4, manifest.playlists.count, "Number of media playlists in master does not match")
      XCTAssertEqual(181, manifest.playlists[3].segments.count, "Segments not correctly parsed")
    }
  }
  
  func testFullParseWithFullPathInManifests() {
    let builder = ManifestBuilder()
    if let url = URL(string: "https://mnmedias.api.telequebec.tv/m3u8/29880.m3u8") {
      let manifest = builder.parse(url, onMediaPlaylist: {
        (media: MediaPlaylist) -> Void in
        XCTAssertNotNil(media.path)
      }, onMediaSegment: {
        (segment: MediaSegment) -> Void in
        let mediaManifestURL = url.URLByReplacingLastPathComponent(segment.mediaPlaylist!.path!)
        let segmentURL = mediaManifestURL!.URLByReplacingLastPathComponent(segment.path!)
        XCTAssertNotNil(segmentURL!.absoluteString)
      })
      XCTAssertEqual(7, manifest.playlists.count, "Number of media playlists in master does not match")
      XCTAssertEqual(105, manifest.playlists[3].segments.count, "Segments not correctly parsed")
    }
  }
}
