cask "duplix" do
  version "1.0.0"
  sha256 "cb45c11837b3cb2aa0f84dc88678a47818b999f7c06e4df3127e0b9e62de3315"

  url "https://github.com/businessmanshah-a11y/Duplix/releases/download/v#{version}/Duplix-#{version}.dmg"
  name "Duplix"
  desc "Free, Native, Open-Source macOS App Cloner with APFS CoW & Dock Badging"
  homepage "https://github.com/businessmanshah-a11y/Duplix"

  depends_on macos: ">= :ventura"

  app "Duplix.app"
  binary "#{appdir}/Duplix.app/Contents/MacOS/duplix"

  zap trash: [
    "~/Applications/Duplix Clones",
    "~/Library/Application Support/Duplix",
    "~/Library/Preferences/com.duplix.app.plist",
  ]
end
