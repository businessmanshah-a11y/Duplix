cask "duplix" do
  version "1.2.0"
  sha256 "cfe8d9ba7a9bbacdff40dfaf9558c5558efd3577d2935a34ec088c50dca05764"

  url "https://businessmanshah-a11y.github.io/Duplix/downloads/Duplix.dmg"
  name "Duplix"
  desc "Free, native, open-source macOS app cloner"
  homepage "https://businessmanshah-a11y.github.io/Duplix/"

  depends_on macos: ">= :sonoma"

  app "Duplix.app"
  binary "#{appdir}/Duplix.app/Contents/MacOS/duplix", target: "duplix"

  zap trash: [
    "~/Library/Application Support/Duplix",
    "~/Library/Preferences/com.duplix.app.plist",
    "~/Library/Saved Application State/com.duplix.app.savedState",
  ]
end
