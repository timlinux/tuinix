package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
)

func runInstallation(c Config) tea.Cmd {
	return func() tea.Msg {
		logInfo("=== Starting installation ===")
		logInfo("Config: Username=%s, Hostname=%s, Disk=%s, StorageMode=%s, EnableSSH=%v", c.Username, c.Hostname, c.Disk, c.StorageMode, c.EnableSSH)
		if c.StorageMode.isMultiDisk() {
			logInfo("Config: Disks=%v", c.Disks)
		}
		logInfo("Config: ProjectRoot=%s, WorkDir=%s", c.ProjectRoot, c.WorkDir)

		step := 0

		logInfo("Step %d: Generating host configuration...", step+1)
		if err := generateHostConfig(c); err != nil {
			logError("generateHostConfig failed: %v", err)
			return installErrMsg{err: fmt.Errorf("generate host config: %w", err)}
		}
		step++
		logInfo("Step %d complete", step)

		logInfo("Step %d: Formatting disk(s)...", step+1)
		if err := formatDisk(c); err != nil {
			logError("formatDisk failed: %v", err)
			return installErrMsg{err: fmt.Errorf("format disk: %w", err)}
		}
		step++
		logInfo("Step %d complete", step)

		logInfo("Step %d: Generating hardware config...", step+1)
		if err := generateHardwareConfig(c); err != nil {
			logError("generateHardwareConfig failed: %v", err)
			return installErrMsg{err: fmt.Errorf("generate hardware config: %w", err)}
		}
		step++
		logInfo("Step %d complete", step)

		logInfo("Step %d: Installing NixOS...", step+1)
		if err := installNixOS(c); err != nil {
			logError("installNixOS failed: %v", err)
			return installErrMsg{err: fmt.Errorf("install nixos: %w", err)}
		}
		step++
		logInfo("Step %d complete", step)

		if c.StorageMode.isZFS() {
			logInfo("Step %d: Configuring ZFS boot...", step+1)
			if err := configureZFSBoot(c); err != nil {
				logError("configureZFSBoot failed: %v", err)
				return installErrMsg{err: fmt.Errorf("configure zfs boot: %w", err)}
			}
			step++
			logInfo("Step %d complete", step)
		}

		logInfo("Step %d: Copying flake...", step+1)
		if err := copyFlake(c); err != nil {
			logError("copyFlake failed: %v", err)
			return installErrMsg{err: fmt.Errorf("copy flake: %w", err)}
		}
		step++
		logInfo("Step %d complete", step)

		logInfo("Step %d: Setting up user flake...", step+1)
		if err := setupUserFlake(c); err != nil {
			logError("setupUserFlake failed: %v", err)
			return installErrMsg{err: fmt.Errorf("setup user flake: %w", err)}
		}
		step++
		logInfo("Step %d complete", step)

		// Copy install log while /mnt is still mounted (before finalization unmounts it)
		logInfo("Step %d: Copying install log...", step+1)
		copyInstallLog(c)
		step++
		logInfo("Step %d complete", step)

		if c.StorageMode.isZFS() {
			logInfo("Step %d: Finalizing ZFS pool...", step+1)
			if err := finalizeZFSPool(c); err != nil {
				logError("finalizeZFSPool failed: %v", err)
				return installErrMsg{err: fmt.Errorf("finalize zfs pool: %w", err)}
			}
			step++
			logInfo("Step %d complete", step)
		}

		logInfo("=== Installation complete ===")
		return installDoneMsg{}
	}
}

func generateHostConfig(c Config) error {
	logInfo("generateHostConfig: starting")
	workDir := c.WorkDir
	logInfo("generateHostConfig: removing old workDir %s", workDir)
	os.RemoveAll(workDir)

	// Create work directory
	logInfo("generateHostConfig: creating workDir %s", workDir)
	if err := os.MkdirAll(workDir, 0755); err != nil {
		return fmt.Errorf("create work dir: %w", err)
	}

	// Check if project root exists
	logInfo("generateHostConfig: checking ProjectRoot %s", c.ProjectRoot)
	if _, err := os.Stat(c.ProjectRoot); os.IsNotExist(err) {
		return fmt.Errorf("project root does not exist: %s", c.ProjectRoot)
	}

	// List contents of project root
	entries, _ := os.ReadDir(c.ProjectRoot)
	logInfo("generateHostConfig: ProjectRoot contents: %d entries", len(entries))
	for _, e := range entries {
		logInfo("  - %s", e.Name())
	}

	// Copy project files, dereferencing symlinks with -L
	logInfo("generateHostConfig: copying project files...")
	if _, err := runCommand("cp", "-rL", c.ProjectRoot+"/.", workDir+"/"); err != nil {
		return fmt.Errorf("copy project from %s to %s: %w", c.ProjectRoot, workDir, err)
	}
	logInfo("generateHostConfig: copy complete")

	hostDir := filepath.Join(workDir, "hosts", c.Hostname)
	logInfo("generateHostConfig: creating hostDir %s", hostDir)
	if err := os.MkdirAll(hostDir, 0755); err != nil {
		return fmt.Errorf("create host dir: %w", err)
	}

	usersDir := filepath.Join(workDir, "users")
	logInfo("generateHostConfig: usersDir is %s", usersDir)

	// Hash the user password
	logInfo("generateHostConfig: hashing user password")
	hashedPassword, err := hashPassword(c.Password)
	if err != nil {
		return fmt.Errorf("hash password: %w", err)
	}
	logInfo("generateHostConfig: password hashed successfully")

	// Build SSH authorized keys section if SSH is enabled
	var sshKeysSection string
	if c.EnableSSH && len(c.SSHKeys) > 0 {
		var keyLines strings.Builder
		for _, key := range c.SSHKeys {
			keyLines.WriteString(fmt.Sprintf("      %q\n", key))
		}
		sshKeysSection = fmt.Sprintf(`    openssh.authorizedKeys.keys = [
%s    ];`, keyLines.String())
	}

	userNix := fmt.Sprintf(`# User configuration for %s
# Generated by tuinix installer on %s
{ config, lib, pkgs, ... }:

{
  users.users.%s = {
    isNormalUser = true;
    description = "%s";
    extraGroups = [ "wheel" "networkmanager" "audio" "video" "docker" ];
    home = "/home/%s";
    createHome = true;
    hashedPassword = "%s";
%s
  };

  home-manager.users.%s = { pkgs, ... }: {
    programs.git = {
      enable = true;
      userName = "%s";
      userEmail = "%s";
      extraConfig = {
        init.defaultBranch = "main";
        pull.rebase = true;
        push.autoSetupRemote = true;
      };
    };
    home.stateVersion = "24.11";
  };
}
`, c.Username, time.Now().UTC().Format("2006-01-02 15:04:05 UTC"),
		c.Username, c.Fullname, c.Username, hashedPassword, sshKeysSection,
		c.Username,
		c.Fullname, c.Email)

	if err := os.WriteFile(filepath.Join(usersDir, c.Username+".nix"), []byte(userNix), 0644); err != nil {
		return fmt.Errorf("write user nix: %w", err)
	}

	// Generate default.nix with conditional ZFS settings
	var zfsConfig string
	if c.StorageMode.isZFS() {
		zfsConfig = `  tuinix.zfs.enable = true;
  tuinix.zfs.encryption = ` + fmt.Sprintf("%v", c.StorageMode.isEncrypted()) + `;`
	} else {
		zfsConfig = `  tuinix.zfs.enable = false;`
	}

	var sshConfig string
	if c.EnableSSH {
		sshConfig = `

  # SSH and firewall
  tuinix.security.ssh.enable = true;
  tuinix.security.firewall.enable = true;`
	}

	defaultNix := fmt.Sprintf(`{ config, lib, pkgs, inputs, hostname, ... }:

{
  imports = [
    ./disks.nix
    ./hardware.nix
    ../../users/%s.nix
    ../../users/admin.nix
  ];

  networking.hostName = hostname;
  system.stateVersion = "25.11";

  environment.systemPackages = with pkgs; [
    vim
    git
  ];

%s
%s
  boot.consoleLogLevel = 3;

  # Enable iPhone USB tethering support
  tuinix.networking.iphone-tethering.enable = true;

  i18n.defaultLocale = "%s";
  services.xserver.xkb.layout = "%s";
  console.keyMap = "%s";
}
`, c.Username, zfsConfig, sshConfig, c.Locale, c.Keymap, c.ConsoleKeyMap)

	if err := os.WriteFile(filepath.Join(hostDir, "default.nix"), []byte(defaultNix), 0644); err != nil {
		return fmt.Errorf("write default.nix: %w", err)
	}

	// Generate disko configuration based on storage mode
	var disksContent string
	switch c.StorageMode {
	case storageXFS:
		templateFile := filepath.Join(workDir, "templates", "disko-xfs.nix")
		templateBytes, err := os.ReadFile(templateFile)
		if err != nil {
			return fmt.Errorf("read xfs disko template: %w", err)
		}
		disksContent = string(templateBytes)
		disksContent = strings.ReplaceAll(disksContent, "{{DISK_DEVICE}}", c.Disk)
		disksContent = strings.ReplaceAll(disksContent, "{{SPACE_BOOT}}", c.SpaceBoot)

	case storageZFSEncryptedSingle:
		templateFile := filepath.Join(workDir, "templates", "disko-template.nix")
		templateBytes, err := os.ReadFile(templateFile)
		if err != nil {
			return fmt.Errorf("read zfs disko template: %w", err)
		}
		disksContent = string(templateBytes)
		disksContent = strings.ReplaceAll(disksContent, "{{DISK_DEVICE}}", c.Disk)
		disksContent = strings.ReplaceAll(disksContent, "{{HOSTNAME}}", c.Hostname)
		disksContent = strings.ReplaceAll(disksContent, "{{SPACE_BOOT}}", c.SpaceBoot)
		disksContent = strings.ReplaceAll(disksContent, "{{SPACE_NIX}}", c.SpaceNix)
		disksContent = strings.ReplaceAll(disksContent, "{{SPACE_ATUIN}}", c.SpaceAtuin)
		disksContent = strings.ReplaceAll(disksContent, "{{ZFS_POOL_NAME}}", c.ZFSPoolName)

	case storageZFSStripe, storageZFSRaidz, storageZFSRaidz2:
		disksContent = generateMultiDiskDiskoConfig(c)
	}

	if err := os.WriteFile(filepath.Join(hostDir, "disks.nix"), []byte(disksContent), 0644); err != nil {
		return fmt.Errorf("write disks.nix: %w", err)
	}

	// hardware.nix is generated later by generateHardwareConfig() after disk formatting,
	// which runs nixos-generate-config to detect actual hardware

	return nil
}

func generateHardwareConfig(c Config) error {
	hostDir := filepath.Join(c.WorkDir, "hosts", c.Hostname)

	os.MkdirAll("/tmp/nixos-config", 0755)
	if _, err := runCommand("nixos-generate-config", "--root", "/mnt", "--dir", "/tmp/nixos-config"); err != nil {
		return fmt.Errorf("nixos-generate-config: %w", err)
	}

	var zfsBootSection string
	var zfsScrubSection string
	var hostIdLine string

	if c.StorageMode.isZFS() {
		hostIdLine = fmt.Sprintf(`  networking.hostId = "%s";`, c.HostID)
		zfsBootSection = fmt.Sprintf(`
  boot = {
    supportedFilesystems = [ "zfs" ];
    zfs = {
      requestEncryptionCredentials = %v;
      forceImportRoot = true;
    };`, c.StorageMode.isEncrypted())
		zfsScrubSection = `
  services.zfs.autoScrub.enable = true;`
	} else {
		hostIdLine = ""
		zfsBootSection = `
  boot = {`
		zfsScrubSection = ""
	}

	hardwareNix := fmt.Sprintf(`{ config, lib, pkgs, modulesPath, ... }:

{
%s
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
%s
    initrd = {
      availableKernelModules = [
        "ahci" "xhci_pci" "virtio_pci" "virtio_blk" "virtio_scsi"
        "sd_mod" "sr_mod" "nvme" "ehci_pci" "usbhid"
        "usb_storage" "sdhci_pci"
      ];
      kernelModules = [ ];
    };
    kernelModules = [ "kvm-intel" "kvm-amd" ];
    extraModulePackages = [ ];
  };

  hardware = {
    enableAllFirmware = true;
    cpu.intel.updateMicrocode = lib.mkDefault true;
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";%s
}
`, hostIdLine, zfsBootSection, zfsScrubSection)

	if err := os.WriteFile(filepath.Join(hostDir, "hardware.nix"), []byte(hardwareNix), 0644); err != nil {
		return fmt.Errorf("write hardware.nix: %w", err)
	}

	return nil
}

func installNixOS(c Config) error {
	os.Setenv("NIX_CONFIG", `
extra-substituters = https://cache.nixos.org/
extra-trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
max-jobs = auto
cores = 0
keep-outputs = true
keep-derivations = true
`)

	flakeRef := fmt.Sprintf("%s#%s", c.WorkDir, c.Hostname)
	if _, err := runCommand("nixos-install", "--flake", flakeRef, "--no-root-passwd"); err != nil {
		return fmt.Errorf("nixos-install: %w", err)
	}

	return nil
}

func configureZFSBoot(c Config) error {
	bootfsPath := fmt.Sprintf("%s/root", c.ZFSPoolName)
	if _, err := runCommand("zpool", "set", "bootfs="+bootfsPath, c.ZFSPoolName); err != nil {
		return fmt.Errorf("set bootfs: %w", err)
	}

	output, err := runCommand("zpool", "get", "-H", "-o", "value", "bootfs", c.ZFSPoolName)
	if err != nil {
		return fmt.Errorf("get bootfs: %w", err)
	}

	if strings.TrimSpace(output) != bootfsPath {
		return fmt.Errorf("bootfs not set correctly, got: %s", output)
	}

	return nil
}

func copyFlake(c Config) error {
	targetDir := "/mnt/etc/tuinix"
	if err := os.MkdirAll(targetDir, 0755); err != nil {
		return fmt.Errorf("create target dir: %w", err)
	}

	if _, err := runCommand("cp", "-r", c.WorkDir+"/.", targetDir+"/"); err != nil {
		return fmt.Errorf("copy flake: %w", err)
	}

	if _, err := runCommand("chown", "-R", "root:root", targetDir); err != nil {
		return fmt.Errorf("chown: %w", err)
	}

	return nil
}

func setupUserFlake(c Config) error {
	userDir := fmt.Sprintf("/mnt/home/%s/tuinix", c.Username)
	hostDir := filepath.Join(c.WorkDir, "hosts", c.Hostname)
	usersDir := filepath.Join(c.WorkDir, "users")
	repoURL := "https://github.com/timlinux/tuinix.git"

	userHome := fmt.Sprintf("/mnt/home/%s", c.Username)
	os.MkdirAll(userHome, 0755)

	os.RemoveAll(userDir)

	if _, err := runCommand("git", "clone", "--depth", "1", repoURL, userDir); err != nil {
		return fmt.Errorf("git clone: %w", err)
	}

	destHostDir := filepath.Join(userDir, "hosts", c.Hostname)
	os.MkdirAll(filepath.Dir(destHostDir), 0755)
	if _, err := runCommand("cp", "-r", hostDir, destHostDir); err != nil {
		return fmt.Errorf("copy host config: %w", err)
	}

	userNixSrc := filepath.Join(usersDir, c.Username+".nix")
	userNixDst := filepath.Join(userDir, "users", c.Username+".nix")
	if _, err := runCommand("cp", userNixSrc, userNixDst); err != nil {
		return fmt.Errorf("copy user config: %w", err)
	}

	runCommand("git", "-C", userDir, "config", "user.name", c.Fullname)
	runCommand("git", "-C", userDir, "config", "user.email", c.Email)

	runCommand("git", "-C", userDir, "add", "hosts/"+c.Hostname, "users/"+c.Username+".nix")

	commitMsg := fmt.Sprintf(`Add host and user configuration for %s

Generated by tuinix installer on %s
Host: %s
User: %s (%s <%s>)
Host ID: %s
Disk: %s
Locale: %s
Keymap: %s`,
		c.Hostname,
		time.Now().UTC().Format("2006-01-02 15:04:05 UTC"),
		c.Hostname,
		c.Username, c.Fullname, c.Email,
		c.HostID,
		c.Disk,
		c.Locale,
		c.Keymap)

	runCommand("git", "-C", userDir, "commit", "-m", commitMsg)

	runCommand("chown", "-R", "1000:100", userHome)

	runCommand("nixos-enter", "--root", "/mnt", "--command",
		fmt.Sprintf("ln -sf /home/%s/tuinix /etc/tuinix-user", c.Username))

	return nil
}

func finalizeZFSPool(c Config) error {
	runCommand("umount", "-R", "/mnt")

	if _, err := runCommand("zpool", "export", c.ZFSPoolName); err != nil {
		return fmt.Errorf("export pool: %w", err)
	}

	if _, err := runCommand("zpool", "import", "-f", c.ZFSPoolName); err != nil {
		return fmt.Errorf("import pool: %w", err)
	}

	if _, err := runCommand("zpool", "export", c.ZFSPoolName); err != nil {
		return fmt.Errorf("final export: %w", err)
	}

	return nil
}

// copyInstallLog copies the install log to the user's home directory on the new system
func copyInstallLog(c Config) {
	targetDir := fmt.Sprintf("/mnt/home/%s", c.Username)
	targetFile := filepath.Join(targetDir, "tuinix-install.log")
	logInfo("Copying install log from %s to %s", logFile, targetFile)

	if _, err := runCommand("cp", logFile, targetFile); err != nil {
		logError("Failed to copy install log: %v", err)
		return
	}
	// Set ownership to the user
	runCommand("chown", "1000:100", targetFile)
	logInfo("Install log copied successfully")
}
