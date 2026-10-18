cask "shelf" do
  version "0.0.6"
  sha256 "10e7844373f36fb471842de4886c3b77870f52e8d35b6772d1385d9e444a8085"

  url "https://github.com/yindia/shelf/releases/download/v#{version}/Shelf.dmg"
  name "Shelf"
  desc "Native macOS clipboard manager with a glass card shelf"
  homepage "https://github.com/yindia/shelf"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sonoma"

  app "Shelf.app"
  auto_updates false

  # The app is ad-hoc signed (not notarized); clear the quarantine flag so it
  # launches without the Gatekeeper prompt.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/Shelf.app"],
                   sudo: false
  end

  zap trash: [
    "~/Library/Application Support/ShelfApp",
    "~/Library/Preferences/com.example.shelf.plist",
  ]
end
