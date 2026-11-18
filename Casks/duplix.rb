cask "duplix" do
  version "1.3.0"
  sha256 "f0087694e9b0e46f6057941ce6f2288f134b4f42e755d6594ec82be39f50558b"

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
