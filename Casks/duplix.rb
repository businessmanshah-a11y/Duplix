cask "duplix" do
  version "1.1.0"
  sha256 "df102d1f37d028018794c5c2d946c0b62d01c4cedc5fedbf4ad363b24bd8f41a"

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
