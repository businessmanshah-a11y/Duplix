import Foundation

/// Bridges Duplix mobile engine with official Android Enterprise / DevicePolicyManager
/// and Package Manager APIs to clone and isolate applications cleanly without root or APK modifications.
public struct AndroidWorkProfileBridge: Sendable {
    public init() {}

    /// Command to clone an already-installed app into an isolated user profile without re-downloading APK.
    public func buildInstallExistingPackageCommand(packageName: String, profileId: Int) -> String {
        return "pm install-existing --user \(profileId) \(packageName)"
    }

    /// Command or API instruction to suspend/freeze an app package to eliminate background battery drain.
    public func buildSuspendPackageCommand(packageName: String, profileId: Int, suspend: Bool) -> String {
        let action = suspend ? "suspend" : "unsuspend"
        return "pm \(action) --user \(profileId) \(packageName)"
    }

    /// Intent action URI used by Android to trigger Voicofski on text selection across all apps.
    public var processTextIntentAction: String {
        return "android.intent.action.PROCESS_TEXT"
    }

    /// Intent filter specification for AndroidManifest.xml.
    public func generateProcessTextActivityManifestSnippet() -> String {
        return """
        <activity android:name=".VoicofskiProcessTextActivity"
            android:label="Duplix Voice"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.PROCESS_TEXT" />
                <category android:name="android.intent.category.DEFAULT" />
                <data android:mimeType="text/plain" />
            </intent-filter>
        </activity>
        """
    }

    /// Generates shell command to provision Work Profile via ADB / Device Admin during setup.
    public func buildProvisionProfileOwnerCommand(componentName: String = "com.duplix.android/.DuplixDeviceAdminReceiver") -> String {
        return "dpm set-profile-owner --name 'Duplix Work' \(componentName)"
    }
}
