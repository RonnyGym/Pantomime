//
// Created by Thomas Christensen on 25/08/16.
// Copyright (c) 2016 Nordija A/S. All rights reserved.
//

import Foundation

/**
 * Parses HTTP Live Streaming manifest files
 * Use a BufferedReader to let the parser read from various sources.
 */
open class ManifestBuilder {
  public init() {}

  /**
   * Parses Master playlist manifests
   */
  fileprivate func parseMasterPlaylist(_ reader: BufferedReader, onMediaPlaylist: ((_ playlist: MediaPlaylist) -> Void)?) -> MasterPlaylist {
    var masterPlaylist = MasterPlaylist()
    var currentMediaPlaylist: MediaPlaylist?

    defer {
      reader.close()
    }

    while let line = reader.readLine() {
      guard !line.isEmpty else {
        continue
      }

      if line.hasPrefix("#EXT") {
        if line.hasPrefix("#EXT-X-STREAM-INF") {
          // #EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=2757000,RESOLUTION=1280x720,CODECS="avc1.4d001f,mp4a.40.2",AUDIO="audio-0"
          currentMediaPlaylist = MediaPlaylist()

          guard let mediaPLInfo = line.split(separator: ":").last?.split(separator: ",").map({ sub -> (key: String, value: String) in
            let kv = sub.split(separator: "=")

            guard kv.count == 2 else {
              print("Failed to parse program-id and bandwidth on master playlist. Line = \(line)")

              return ("", "")
            }

            guard let key = kv.first?.trimmingCharacters(in: .whitespaces), let value = kv.last?.trimmingCharacters(in: .whitespaces) else {
              print("Failed to parse program-id and bandwidth on master playlist. Line = \(line)")

              return ("", "")
            }

            return (String(key), String(value))
          }) else {
            print("Failed to parse program-id and bandwidth on master playlist. Line = \(line)")

            continue
          }

          if let programIdString = mediaPLInfo.first(where: { $0.key == "PROGRAM-ID" })?.value, let programId = Int(programIdString) {
            currentMediaPlaylist?.programId = programId
          } else {
            print("Failed to parse program-id on master playlist. Line = \(line)")
          }

          if let bandwidthString = mediaPLInfo.first(where: { $0.key == "BANDWIDTH" })?.value, let bandwidth = Double(bandwidthString) {
            currentMediaPlaylist?.bandwidth = bandwidth
          } else {
            print("Failed to parse bandwidth on master playlist. Line = \(line)")
          }

          if let resolutionString = mediaPLInfo.first(where: { $0.key == "RESOLUTION" })?.value {
            let widthHeight = resolutionString.split(separator: "x")

            if let widthString = widthHeight.first, let width = Int(String(widthString)), let heightString = widthHeight.last, let height = Int(String(heightString)) {
              currentMediaPlaylist?.resolution = Resolution(width: width, height: height)
            }
          }
        }
      } else if line.hasPrefix("#") {
        continue
      } else {
        if let currentMediaPlaylistExist = currentMediaPlaylist {
          currentMediaPlaylistExist.path = line
          currentMediaPlaylistExist.masterPlaylist = masterPlaylist
          masterPlaylist.addPlaylist(currentMediaPlaylistExist)

          if let callableOnMediaPlaylist = onMediaPlaylist {
            callableOnMediaPlaylist(currentMediaPlaylistExist)
          }
        }
      }
    }

    return masterPlaylist
  }

  private func parseMediaPlaylistExtXKey(_ line: String) -> XKey? {
    // #EXT-X-KEY:METHOD=SAMPLE-AES,URI="skd://twelve",KEYFORMAT="com.apple.streamingkeydelivery",
    //   KEYFORMATVERSIONS="1"
    // #EXT-X-KEY:METHOD=AES-128,URI="https://my-host/?foo=bar",IV="0x0123456789ABCDEF"

    guard let parametersString = try? line.replace("#EXT-X-KEY:", replacement: "") else {
      print("Failed to parse X-KEY on media playlist. Line = \(line)")
      return nil
    }

    return parseExtXKey(parametersString)
  }

  private func parseExtXKey(_ parametersString: String) -> XKey? {
    let parameters = parametersString.m3u8_parseLine()

    guard let method = parameters["METHOD"],
      let uriString = parameters["URI"] else {
        return nil
    }

    let iv = parameters["IV"]
    let keyFormat = parameters["KEYFORMAT"]
    let keyFormatVersions = parameters["KEYFORMATVERSIONS"]

    return XKey(method: method, uri: uriString, iv: iv, keyFormat: keyFormat, keyFormatVersions: keyFormatVersions)
  }

  /**
   * Parses Media Playlist manifests
   */
  fileprivate func parseMediaPlaylist(_ reader: BufferedReader, mediaPlaylist: MediaPlaylist = MediaPlaylist(), onMediaSegment: ((_ segment: MediaSegment) -> Void)?) -> MediaPlaylist {
    var xKey: XKey?
    var currentSegment: MediaSegment?
    var currentURI: String?
    var currentSequence = 0

    defer {
      reader.close()
    }

    while let line = reader.readLine() {
      guard !line.isEmpty else {
        continue
      }

      if line.hasPrefix("#EXT") {
        if line.hasPrefix("#EXT-X-VERSION") {
          do {
            let version = try line.replace("(.*):(\\d+)(.*)", replacement: "$2")

            mediaPlaylist.version = Int(version)
          } catch {
            print("Failed to parse the version of media playlist. Line = \(line)")
          }

        } else if line.hasPrefix("#EXT-X-TARGETDURATION") {
          do {
            let durationString = try line.replace("(.*):(\\d+)(.*)", replacement: "$2")

            mediaPlaylist.targetDuration = Int(durationString)
          } catch {
            print("Failed to parse the target duration of media playlist. Line = \(line)")
          }

        } else if line.hasPrefix("#EXT-X-MEDIA-SEQUENCE") {
          do {
            let mediaSequence = try line.replace("(.*):(\\d+)(.*)", replacement: "$2")

            if let mediaSequenceExtracted = Int(mediaSequence) {
              mediaPlaylist.mediaSequence = mediaSequenceExtracted
              currentSequence = mediaSequenceExtracted
            }
          } catch {
            print("Failed to parse the media sequence in media playlist. Line = \(line)")
          }

        } else if line.hasPrefix("#EXTINF") {
          currentSegment = MediaSegment()

          do {
            let segmentDurationString = try line.replace("(.*):(\\d.*),(.*)", replacement: "$2")
            let segmentTitle = try line.replace("(.*):(\\d.*),(.*)", replacement: "$3")

            currentSegment!.duration = Float(segmentDurationString)
            currentSegment!.title = segmentTitle
          } catch {
            print("Failed to parse the segment duration and title. Line = \(line)")
          }
        } else if line.hasPrefix("#EXT-X-BYTERANGE") {
          if line.contains("@") {
            do {
              let subrangeLength = try line.replace("(.*):(\\d.*)@(.*)", replacement: "$2")
              let subrangeStart = try line.replace("(.*):(\\d.*)@(.*)", replacement: "$3")

              currentSegment!.subrangeLength = Int(subrangeLength)
              currentSegment!.subrangeStart = Int(subrangeStart)
            } catch {
              print("Failed to parse byte range. Line = \(line)")
            }
          } else {
            do {
              let subrangeLength = try line.replace("(.*):(\\d.*)", replacement: "$2")

              currentSegment!.subrangeLength = Int(subrangeLength)
              currentSegment!.subrangeStart = nil
            } catch {
              print("Failed to parse the byte range. Line = \(line)")
            }
          }
        } else if line.hasPrefix("#EXT-X-DISCONTINUITY") {
          currentSegment!.discontinuity = true
        } else if line.hasPrefix("#EXT-X-KEY") {
          xKey = parseMediaPlaylistExtXKey(line)
        }

      } else if line.hasPrefix("#") {
        // Comments are ignored

      } else {
        // URI - must be
        if let currentSegmentExists = currentSegment {
          currentSegmentExists.mediaPlaylist = mediaPlaylist
          currentSegmentExists.path = line
          currentSegmentExists.sequence = currentSequence
          currentSegmentExists.xKey = xKey
          currentSequence += 1
          mediaPlaylist.addSegment(currentSegmentExists)

          if let callableOnMediaSegment = onMediaSegment {
            callableOnMediaSegment(currentSegmentExists)
          }
        }
      }
    }

    return mediaPlaylist
  }

  /**
   * Parses the master playlist manifest from a string document.
   *
   * Convenience method that uses a StringBufferedReader as source for the manifest.
   */
  open func parseMasterPlaylistFromString(_ string: String, onMediaPlaylist:
    ((_ playlist: MediaPlaylist) -> Void)? = nil) -> MasterPlaylist {
    return parseMasterPlaylist(StringBufferedReader(string: string), onMediaPlaylist: onMediaPlaylist)
  }

  /**
   * Parses the master playlist manifest from a file.
   *
   * Convenience method that uses a FileBufferedReader as source for the manifest.
   */
  open func parseMasterPlaylistFromFile(_ path: String, onMediaPlaylist:
    ((_ playlist: MediaPlaylist) -> Void)? = nil) -> MasterPlaylist {
    return parseMasterPlaylist(FileBufferedReader(path: path), onMediaPlaylist: onMediaPlaylist)
  }

  /**
   * Parses the master playlist manifest requested synchronous from a URL
   *
   * Convenience method that uses a URLBufferedReader as source for the manifest.
   */
  open func parseMasterPlaylistFromURL(_ url: URL, onMediaPlaylist:
    ((_ playlist: MediaPlaylist) -> Void)? = nil) -> MasterPlaylist {
    return parseMasterPlaylist(URLBufferedReader(uri: url), onMediaPlaylist: onMediaPlaylist)
  }

  /**
   * Parses the media playlist manifest from a string document.
   *
   * Convenience method that uses a StringBufferedReader as source for the manifest.
   */
  open func parseMediaPlaylistFromString(_ string: String,
                                         mediaPlaylist: MediaPlaylist = MediaPlaylist(),
                                         onMediaSegment:((_ segment: MediaSegment) -> Void)? = nil) -> MediaPlaylist {
    return parseMediaPlaylist(StringBufferedReader(string: string),
                              mediaPlaylist: mediaPlaylist, onMediaSegment: onMediaSegment)
  }

  /**
   * Parses the media playlist manifest from a file document.
   *
   * Convenience method that uses a FileBufferedReader as source for the manifest.
   */
  open func parseMediaPlaylistFromFile(_ path: String,
                                       mediaPlaylist: MediaPlaylist = MediaPlaylist(),
                                       onMediaSegment: ((_ segment: MediaSegment) -> Void)? = nil) -> MediaPlaylist {
    return parseMediaPlaylist(FileBufferedReader(path: path),
                              mediaPlaylist: mediaPlaylist, onMediaSegment: onMediaSegment)
  }

  /**
   * Parses the media playlist manifest requested synchronous from a URL
   *
   * Convenience method that uses a URLBufferedReader as source for the manifest.
   */
  @discardableResult
  open func parseMediaPlaylistFromURL(_ url: URL,
                                      mediaPlaylist: MediaPlaylist = MediaPlaylist(),
                                      onMediaSegment: ((_ segment: MediaSegment) -> Void)? = nil) -> MediaPlaylist {
    return parseMediaPlaylist(URLBufferedReader(uri: url),
                              mediaPlaylist: mediaPlaylist, onMediaSegment: onMediaSegment)
  }

  /**
   * Parses the master manifest found at the URL and all the referenced media playlist manifests recursively.
   */
  open func parse(_ url: URL,
                  onMediaPlaylist: ((_ playlist: MediaPlaylist) -> Void)? = nil,
                  onMediaSegment: ((_ segment: MediaSegment) -> Void)? = nil) -> MasterPlaylist {
    // Parse master
    let master = parseMasterPlaylistFromURL(url, onMediaPlaylist: onMediaPlaylist)
    for playlist in master.playlists {
      if let path = playlist.path {

        // Detect if manifests are referred to with protocol
        if path.hasPrefix("http") || path.hasPrefix("file") {
          // Full path used
          if let mediaURL = URL(string: path) {
            parseMediaPlaylistFromURL(mediaURL,
                                      mediaPlaylist: playlist, onMediaSegment: onMediaSegment)
          }
        } else {
          // Relative path used
          if let mediaURL = url.URLByReplacingLastPathComponent(path) {
            parseMediaPlaylistFromURL(mediaURL,
                                      mediaPlaylist: playlist, onMediaSegment: onMediaSegment)
          }
        }
      }
    }
    return master
  }
}
