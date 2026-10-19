cask "shelf" do
  version "0.0.7"
  sha256 "6e62a4a85edead1203282c63908bc1f42f544ce19ab4c6ae5e0c362da679d2db"

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
    "~/Library/Preferences/com.yindia.shelf.plist",
  ]
end
