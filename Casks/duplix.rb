cask "duplix" do
  version "1.4.0"
  sha256 "9b1a18a23378c90b0dec2c17bac81f5dec2c29ea314bdd9736ed961fb23d546e"

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
