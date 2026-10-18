cask "shelf" do
  version "0.0.4"
  sha256 "7bd51e3435336153dcb64d045b79cef38a948bd21bd57fb7208b51593b11c2bc"

  url "https://github.com/yindia/shelf/releases/download/v#{version}/Shelf.dmg"
  name "Shelf"
  desc "Native macOS clipboard manager with a glass card shelf"
  homepage "https://github.com/yindia/shelf"

  depends_on macos: ">= :sonoma"

  app "Shelf.app"

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
