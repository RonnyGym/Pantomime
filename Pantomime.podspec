Pod::Spec.new do |s|
  s.name         = "Pantomime"
  s.version      = "0.1.5"
  s.summary      = "Parsing of M3U8 manifest files for Swift"

  s.description      = <<-DESC
    M3U8Parser4Swift reads and writes HTTP Live Streaming manifest files.
    Use it to fetch a Master manifest and for parsing it. Supports the
    Internet-Draft version 7. Can be used to throw events when various elements
    have been parsed. Use it to contruct a new manifest from scratch.
    Supports Master and Media playlist manifest files.
                       DESC

  s.homepage     = "https://github.com/RonnyGym/Pantomime.git"
  s.license      = "MIT"
  s.author       = { "Thomas Christensen" => "tchristensen@nordija.com" }
  s.ios.deployment_target = "8.0"
  s.tvos.deployment_target = "9.0"
  s.source       = { :git => "https://github.com/RonnyGym/Pantomime.git", :tag => s.version }
  s.source_files  = "sources"
end
