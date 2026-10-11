cask "duplix" do
  version "1.0.0"
  sha256 "cb45c11837b3cb2aa0f84dc88678a47818b999f7c06e4df3127e0b9e62de3315"

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
