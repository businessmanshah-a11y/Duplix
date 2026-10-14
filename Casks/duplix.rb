cask "duplix" do
  version "1.0.0"
  sha256 "1c39945b615a107585d0f150dde405b7861a506586b31872befa61f19ab17b38"

  url "https://businessmanshah-a11y.github.io/Duplix/downloads/Duplix.dmg"
  name "Duplix"
  desc "Free, native, open-source macOS app cloner"
  homepage "https://businessmanshah-a11y.github.io/Duplix/"

  depends_on macos: ">= :sonoma"

  app "Duplix.app"
  binary "#{appdir}/Duplix.app/Contents/MacOS/duplix", target: "duplix"

  zap trash: [
    "~/Library/Application Support/Duplix",
    "~/Library/Preferences/com.businessmanshah.duplix.plist",
    "~/Library/Saved Application State/com.businessmanshah.duplix.savedState",
  ]
end
