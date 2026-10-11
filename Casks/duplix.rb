cask "duplix" do
  version "1.0.0"
  sha256 "48710b70bbf35b241e8fd3995682fdbee2f16b2b7e228575155a335c07b557dc"

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
