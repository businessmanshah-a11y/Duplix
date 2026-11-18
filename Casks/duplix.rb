cask "duplix" do
  version "1.4.0"
  sha256 "c70a3fba190baabd1f5324a1cffa1becbf4ecb5a929eecbc61df51091f707593"

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
