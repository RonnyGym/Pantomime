//
// Created by Thomas Christensen on 24/08/16.
// Copyright (c) 2016 Nordija A/S. All rights reserved.
//

import Foundation

public typealias Resolution = (width: Int, height: Int)

open class MediaPlaylist {
  open weak var masterPlaylist: MasterPlaylist?

  open var programId: Int = 0
  open var bandwidth: Double = 0
  open var resolution: Resolution?
  open var path: String?
  open var version: Int?
  open var targetDuration: Int?
  open var mediaSequence: Int?
  var segments = [MediaSegment]()

  public init() {

  }

  open func addSegment(_ segment: MediaSegment) {
    segments.append(segment)
  }

  open func getSegment(_ index: Int) -> MediaSegment? {
    if index >= segments.count {
      return nil
    }
    return segments[index]
  }

  open func getSegmentCount() -> Int {
    return segments.count
  }

  open func duration() -> Float {
    var dur: Float = 0.0
    for item in segments {
      dur += item.duration!
    }
    return dur
  }

  open func getMaster() -> MasterPlaylist? {
    return self.masterPlaylist
  }
}
