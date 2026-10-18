cask "shelf" do
  version "0.0.5"
  sha256 "84c7801ed446fda8bf40977f09538bf796ee4373c2b409ac9ccc1759973c931b"

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
