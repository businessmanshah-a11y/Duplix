package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

type ProfileMetadata struct {
	Name       string    `json:"name"`
	AppPath    string    `json:"app_path"`
	CreatedAt  time.Time `json:"created_at"`
	LastLaunch time.Time `json:"last_launch"`
}

func getDuplixRootDir() string {
	localAppData := os.Getenv("LOCALAPPDATA")
	if localAppData == "" {
		home, _ := os.UserHomeDir()
		localAppData = filepath.Join(home, "AppData", "Local")
	}
	return filepath.Join(localAppData, "Duplix")
}

func getInstallDir() string {
	localAppData := os.Getenv("LOCALAPPDATA")
	if localAppData == "" {
		home, _ := os.UserHomeDir()
		localAppData = filepath.Join(home, "AppData", "Local")
	}
	return filepath.Join(localAppData, "Programs", "Duplix")
}

func installToSystem() error {
	selfPath, err := os.Executable()
	if err != nil {
		return err
	}

	installDir := getInstallDir()
	if err := os.MkdirAll(installDir, 0755); err != nil {
		return err
	}

	targetExe := filepath.Join(installDir, "duplix.exe")
	if strings.ToLower(selfPath) != strings.ToLower(targetExe) {
		src, err := os.Open(selfPath)
		if err == nil {
			defer src.Close()
			dst, err := os.Create(targetExe)
			if err == nil {
				defer dst.Close()
				io.Copy(dst, src)
			}
		}
	}

	// Add to User PATH via PowerShell
	psCmd := fmt.Sprintf(`
		$installDir = '%s'
		$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
		if ($userPath -notlike "*$installDir*") {
			[Environment]::SetEnvironmentVariable('Path', "$userPath;$installDir", 'User')
		}
		
		$desktop = [Environment]::GetFolderPath('Desktop')
		$ws = New-Object -ComObject WScript.Shell
		$sc = $ws.CreateShortcut("$desktop\Duplix.lnk")
		$sc.TargetPath = "$installDir\duplix.exe"
		$sc.WorkingDirectory = "$installDir"
		$sc.Description = "Duplix Native App Cloner"
		$sc.Save()

		$startMenu = [Environment]::GetFolderPath('Programs')
		$sc2 = $ws.CreateShortcut("$startMenu\Duplix.lnk")
		$sc2.TargetPath = "$installDir\duplix.exe"
		$sc2.WorkingDirectory = "$installDir"
		$sc2.Description = "Duplix Native App Cloner"
		$sc2.Save()
	`, installDir)

	cmd := exec.Command("powershell", "-NoProfile", "-NonInteractive", "-Command", psCmd)
	_ = cmd.Run()

	return nil
}

func launchClone(appPath string, profileName string, extraArgs ...string) error {
	rootDir := getDuplixRootDir()
	profileDir := filepath.Join(rootDir, "Profiles", profileName)
	dataDir := filepath.Join(profileDir, "Data")

	if err := os.MkdirAll(dataDir, 0755); err != nil {
		return fmt.Errorf("failed to create profile directory: %w", err)
	}

	meta := ProfileMetadata{
		Name:       profileName,
		AppPath:    appPath,
		CreatedAt:  time.Now(),
		LastLaunch: time.Now(),
	}
	metaFile := filepath.Join(profileDir, "metadata.json")
	if data, err := json.MarshalIndent(meta, "", "  "); err == nil {
		_ = os.WriteFile(metaFile, data, 0644)
	}

	args := []string{
		fmt.Sprintf("--user-data-dir=%s", dataDir),
	}
	args = append(args, extraArgs...)

	cmd := exec.Command(appPath, args...)
	if err := cmd.Start(); err != nil {
		return fmt.Errorf("failed to launch application: %w", err)
	}

	fmt.Printf("[✔] Launched %s in isolated profile '%s' (PID %d)\n", filepath.Base(appPath), profileName, cmd.Process.Pid)
	return nil
}

func listProfiles() {
	rootDir := getDuplixRootDir()
	profilesDir := filepath.Join(rootDir, "Profiles")

	entries, err := os.ReadDir(profilesDir)
	if err != nil || len(entries) == 0 {
		fmt.Println("No active clones created yet.")
		return
	}

	fmt.Println("\nActive Duplix Clones:")
	fmt.Println("---------------------------------------------------------------")
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		pName := entry.Name()
		metaPath := filepath.Join(profilesDir, pName, "metadata.json")
		dataPath := filepath.Join(profilesDir, pName, "Data")

		appStr := "Unknown Target"
		if metaBytes, err := os.ReadFile(metaPath); err == nil {
			var m ProfileMetadata
			if json.Unmarshal(metaBytes, &m) == nil && m.AppPath != "" {
				appStr = filepath.Base(m.AppPath)
			}
		}

		fmt.Printf(" • Profile: %-15s | App: %-18s | Path: %s\n", pName, appStr, dataPath)
	}
	fmt.Println("---------------------------------------------------------------")
}

func findCommonApp(name string) string {
	programFiles := os.Getenv("ProgramFiles")
	programFilesX86 := os.Getenv("ProgramFiles(x86)")
	localAppData := os.Getenv("LOCALAPPDATA")
	appData := os.Getenv("APPDATA")

	candidates := []string{}
	switch strings.ToLower(name) {
	case "chrome":
		candidates = []string{
			filepath.Join(programFiles, "Google", "Chrome", "Application", "chrome.exe"),
			filepath.Join(programFilesX86, "Google", "Chrome", "Application", "chrome.exe"),
			filepath.Join(localAppData, "Google", "Chrome", "Application", "chrome.exe"),
		}
	case "edge":
		candidates = []string{
			filepath.Join(programFilesX86, "Microsoft", "Edge", "Application", "msedge.exe"),
			filepath.Join(programFiles, "Microsoft", "Edge", "Application", "msedge.exe"),
		}
	case "vscode", "code":
		candidates = []string{
			filepath.Join(localAppData, "Programs", "Microsoft VS Code", "Code.exe"),
			filepath.Join(programFiles, "Microsoft VS Code", "Code.exe"),
		}
	case "discord":
		candidates = []string{
			filepath.Join(localAppData, "Discord", "Update.exe"),
			filepath.Join(localAppData, "Discord", "app-1.0.9000", "Discord.exe"),
		}
	case "telegram":
		candidates = []string{
			filepath.Join(appData, "Telegram Desktop", "Telegram.exe"),
			filepath.Join(programFiles, "Telegram Desktop", "Telegram.exe"),
		}
	case "slack":
		candidates = []string{
			filepath.Join(localAppData, "slack", "slack.exe"),
			filepath.Join(programFiles, "Slack", "slack.exe"),
		}
	}

	for _, c := range candidates {
		if c != "" {
			if _, err := os.Stat(c); err == nil {
				return c
			}
		}
	}
	return ""
}

func interactiveMenu() {
	reader := bufio.NewReader(os.Stdin)

	for {
		fmt.Println(`
=====================================================================
                    DUPLIX FOR WINDOWS (v1.4.0)
         Native App Cloner & Complete Session Sandbox
=====================================================================
Architecture: ` + runtime.GOARCH + ` | OS: Windows 10/11
Storage Dir:  ` + getDuplixRootDir() + `

Select an option:
  [1] Clone Google Chrome (Personal / Work Profile)
  [2] Clone Microsoft Edge
  [3] Clone VS Code (Independent Dev Environment)
  [4] Clone Discord / Slack / Telegram
  [5] Clone Custom Application (.exe path)
  [6] View Active Clones & Data Folders
  [7] Open Profiles Folder in File Explorer
  [8] Reinstall / Repair Windows PATH & Desktop Shortcuts
  [0] Exit
`)
		fmt.Print("Enter choice [0-8]: ")
		choice, _ := reader.ReadString('\n')
		choice = strings.TrimSpace(choice)

		switch choice {
		case "1":
			chrome := findCommonApp("chrome")
			if chrome == "" {
				fmt.Print("Google Chrome not found in standard paths. Enter full chrome.exe path: ")
				chrome, _ = reader.ReadString('\n')
				chrome = strings.TrimSpace(chrome)
			}
			if chrome != "" {
				fmt.Print("Enter new profile name (e.g. Work-Chrome): ")
				pName, _ := reader.ReadString('\n')
				pName = strings.TrimSpace(pName)
				if pName == "" {
					pName = fmt.Sprintf("Chrome-%d", time.Now().Unix()%1000)
				}
				launchClone(chrome, pName)
			}

		case "2":
			edge := findCommonApp("edge")
			if edge == "" {
				fmt.Print("Enter full msedge.exe path: ")
				edge, _ = reader.ReadString('\n')
				edge = strings.TrimSpace(edge)
			}
			if edge != "" {
				fmt.Print("Enter new profile name (e.g. Shop-Edge): ")
				pName, _ := reader.ReadString('\n')
				pName = strings.TrimSpace(pName)
				if pName == "" {
					pName = fmt.Sprintf("Edge-%d", time.Now().Unix()%1000)
				}
				launchClone(edge, pName)
			}

		case "3":
			code := findCommonApp("vscode")
			if code == "" {
				fmt.Print("VS Code not found. Enter full Code.exe path: ")
				code, _ = reader.ReadString('\n')
				code = strings.TrimSpace(code)
			}
			if code != "" {
				fmt.Print("Enter new profile name (e.g. Client-Project): ")
				pName, _ := reader.ReadString('\n')
				pName = strings.TrimSpace(pName)
				if pName == "" {
					pName = fmt.Sprintf("VSCode-%d", time.Now().Unix()%1000)
				}
				launchClone(code, pName)
			}

		case "4":
			fmt.Println("\nAvailable messenger/social targets:")
			fmt.Println("  [A] Telegram Desktop")
			fmt.Println("  [B] Discord")
			fmt.Println("  [C] Slack")
			fmt.Print("Choice (A/B/C): ")
			subChoice, _ := reader.ReadString('\n')
			subChoice = strings.ToUpper(strings.TrimSpace(subChoice))

			var appTarget string
			switch subChoice {
			case "A":
				appTarget = findCommonApp("telegram")
			case "B":
				appTarget = findCommonApp("discord")
			case "C":
				appTarget = findCommonApp("slack")
			}

			if appTarget == "" {
				fmt.Print("Enter full .exe path of the messaging application: ")
				appTarget, _ = reader.ReadString('\n')
				appTarget = strings.TrimSpace(appTarget)
			}

			if appTarget != "" {
				fmt.Print("Enter profile name: ")
				pName, _ := reader.ReadString('\n')
				pName = strings.TrimSpace(pName)
				if pName == "" {
					pName = fmt.Sprintf("Social-%d", time.Now().Unix()%1000)
				}
				launchClone(appTarget, pName)
			}

		case "5":
			fmt.Print("Enter complete path to target .exe: ")
			targetExe, _ := reader.ReadString('\n')
			targetExe = strings.Trim(strings.TrimSpace(targetExe), "\"")

			if targetExe != "" {
				fmt.Print("Enter profile name: ")
				pName, _ := reader.ReadString('\n')
				pName = strings.TrimSpace(pName)
				if pName == "" {
					pName = fmt.Sprintf("Clone-%d", time.Now().Unix()%1000)
				}
				launchClone(targetExe, pName)
			}

		case "6":
			listProfiles()

		case "7":
			rootDir := getDuplixRootDir()
			profilesDir := filepath.Join(rootDir, "Profiles")
			_ = os.MkdirAll(profilesDir, 0755)
			exec.Command("explorer.exe", profilesDir).Start()

		case "8":
			fmt.Println("Installing Duplix and registering Desktop/Start Menu shortcuts...")
			if err := installToSystem(); err != nil {
				fmt.Printf("[!] Installation error: %v\n", err)
			} else {
				fmt.Println("[✔] Installed successfully to User Programs and added to PATH.")
			}

		case "0":
			fmt.Println("Exiting Duplix. Goodbye!")
			return

		default:
			fmt.Println("Invalid selection. Please choose an option from the menu.")
		}

		fmt.Print("\nPress Enter to return to menu...")
		reader.ReadString('\n')
	}
}

func main() {
	// Auto-install shortcuts on first run
	installDir := getInstallDir()
	selfPath, _ := os.Executable()
	if !strings.EqualFold(filepath.Dir(selfPath), installDir) {
		_ = installToSystem()
	}

	if len(os.Args) == 1 {
		interactiveMenu()
		return
	}

	cmd := os.Args[1]
	switch cmd {
	case "install":
		if err := installToSystem(); err != nil {
			fmt.Fprintf(os.Stderr, "Installation failed: %v\n", err)
			os.Exit(1)
		}
		fmt.Println("[✔] Duplix installed successfully to Windows system.")

	case "clone", "launch":
		if len(os.Args) < 4 {
			fmt.Println("Usage: duplix clone <path-to-app.exe> <profile-name> [extra-args...]")
			os.Exit(1)
		}
		appPath := os.Args[2]
		profileName := os.Args[3]
		extraArgs := os.Args[4:]
		if err := launchClone(appPath, profileName, extraArgs...); err != nil {
			fmt.Fprintf(os.Stderr, "Launch failed: %v\n", err)
			os.Exit(1)
		}

	case "list":
		listProfiles()

	case "help", "-h", "--help":
		fmt.Println(`Duplix Windows CLI (v1.4.0)
Commands:
  duplix                              Open interactive launcher menu
  duplix clone <app.exe> <profile>    Clone application into isolated session
  duplix list                         List active clones and data directories
  duplix install                      Register shortcuts and PATH environment`)

	default:
		fmt.Printf("Unknown command: %s. Run 'duplix help' for usage.\n", cmd)
		os.Exit(1)
	}
}
