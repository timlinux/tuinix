package main

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func getAvailableDisks() []diskInfo {
	var disks []diskInfo

	cmd := exec.Command("lsblk", "-d", "-n", "-o", "NAME,SIZE,TYPE,MODEL")
	output, err := cmd.Output()
	if err != nil {
		return []diskInfo{{Path: "/dev/sda", Size: "100G", Model: "Test Disk"}}
	}

	lines := strings.Split(string(output), "\n")
	for _, line := range lines {
		fields := strings.Fields(line)
		if len(fields) >= 3 && fields[2] == "disk" {
			model := ""
			if len(fields) >= 4 {
				model = strings.Join(fields[3:], " ")
			}
			disks = append(disks, diskInfo{
				Path:  "/dev/" + fields[0],
				Size:  fields[1],
				Model: model,
			})
		}
	}

	if len(disks) == 0 {
		disks = []diskInfo{{Path: "/dev/sda", Size: "100G", Model: "No disks found"}}
	}

	return disks
}

func getAvailablePartitions(disk string) []partitionInfo {
	var partitions []partitionInfo

	cmd := exec.Command("lsblk", "-n", "-o", "NAME,SIZE,TYPE,FSTYPE,PARTLABEL", disk)
	output, err := cmd.Output()
	if err != nil {
		return []partitionInfo{{Path: disk + "1", Size: "500M", FSType: "vfat", Label: "EFI System"}}
	}

	lines := strings.Split(string(output), "\n")
	for _, line := range lines {
		fields := strings.Fields(line)
		if len(fields) >= 3 && fields[2] == "part" {
			fsType := ""
			if len(fields) >= 4 {
				fsType = fields[3]
			}
			label := ""
			if len(fields) >= 5 {
				label = strings.Join(fields[4:], " ")
			}
			partitions = append(partitions, partitionInfo{
				Path:   "/dev/" + fields[0],
				Size:   fields[1],
				FSType: fsType,
				Label:  label,
			})
		}
	}

	if len(partitions) == 0 {
		partitions = []partitionInfo{{Path: disk + "1", Size: "unknown", FSType: "", Label: "No partitions found"}}
	}

	return partitions
}

func calculateSpaceAllocation(c *Config) {
	// For multi-disk ZFS, calculate total pool size across all disks
	// (excluding the boot partition on the first disk)
	var totalSizeGB int64

	if c.StorageMode.isMultiDisk() {
		for _, disk := range c.Disks {
			sizeGB := getDiskSizeGB(disk)
			totalSizeGB += sizeGB
		}
		// For raidz, usable space is roughly (N-1)/N of total
		// For raidz2, usable space is roughly (N-2)/N of total
		// For stripe, usable space is total
		n := int64(len(c.Disks))
		switch c.StorageMode {
		case storageZFSRaidz:
			totalSizeGB = totalSizeGB * (n - 1) / n
		case storageZFSRaidz2:
			totalSizeGB = totalSizeGB * (n - 2) / n
		}
	} else {
		totalSizeGB = getDiskSizeGB(c.Disk)
	}

	if totalSizeGB == 0 {
		totalSizeGB = 100
	}

	bootGB := int64(5)
	c.SpaceBoot = fmt.Sprintf("%dG", bootGB)

	if c.StorageMode.usesPartitions() {
		// Partition mode: using existing partitions, no space allocation needed
		c.SpaceBoot = "(existing)"
		c.SpaceNix = ""
		c.SpaceAtuin = ""
		c.SpaceHome = ""
		return
	}

	if !c.StorageMode.isZFS() {
		// XFS: just boot + root, no separate partitions
		c.SpaceNix = ""
		c.SpaceAtuin = ""
		c.SpaceHome = ""
		return
	}

	// The boot partition is separate from the ZFS pool, so subtract it
	// from the first disk's contribution to get actual pool size
	poolSizeGB := totalSizeGB - bootGB

	nixGB := poolSizeGB * 5 / 100
	if nixGB < 20 {
		nixGB = 20
	}
	atuinGB := poolSizeGB * 5 / 10000
	if atuinGB < 1 {
		atuinGB = 1
	}
	homeGB := poolSizeGB - nixGB - atuinGB

	c.SpaceNix = fmt.Sprintf("%dG", nixGB)
	c.SpaceAtuin = fmt.Sprintf("%dG", atuinGB)
	c.SpaceHome = fmt.Sprintf("%dG", homeGB)
}

func getDiskSizeGB(disk string) int64 {
	cmd := exec.Command("lsblk", "-d", "-n", "-b", "-o", "SIZE", disk)
	output, err := cmd.Output()
	if err != nil {
		return 100
	}
	var sizeBytes int64
	fmt.Sscanf(strings.TrimSpace(string(output)), "%d", &sizeBytes)
	sizeGB := sizeBytes / 1024 / 1024 / 1024
	if sizeGB == 0 {
		sizeGB = 100
	}
	return sizeGB
}

func formatPartitions(c Config) error {
	logInfo("formatPartitions: starting partition mode")
	logInfo("formatPartitions: root=%s, boot=%s", c.RootPartition, c.BootPartition)

	// Format root partition with XFS
	logInfo("formatPartitions: formatting %s with XFS", c.RootPartition)
	if _, err := runCommand("mkfs.xfs", "-f", c.RootPartition); err != nil {
		return fmt.Errorf("mkfs.xfs %s: %w", c.RootPartition, err)
	}

	// Mount root partition
	logInfo("formatPartitions: mounting %s at /mnt", c.RootPartition)
	os.MkdirAll("/mnt", 0755)
	if _, err := runCommand("mount", c.RootPartition, "/mnt"); err != nil {
		return fmt.Errorf("mount %s: %w", c.RootPartition, err)
	}

	// Mount boot partition
	logInfo("formatPartitions: mounting %s at /mnt/boot", c.BootPartition)
	os.MkdirAll("/mnt/boot", 0755)
	if _, err := runCommand("mount", c.BootPartition, "/mnt/boot"); err != nil {
		return fmt.Errorf("mount %s: %w", c.BootPartition, err)
	}

	logInfo("formatPartitions: completed successfully")
	return nil
}

func formatDisk(c Config) error {
	logInfo("formatDisk: starting")

	// Partition mode: skip disko, format and mount manually
	if c.StorageMode.usesPartitions() {
		return formatPartitions(c)
	}

	hostDir := filepath.Join(c.WorkDir, "hosts", c.Hostname)
	diskoConfig := filepath.Join(hostDir, "disks.nix")
	logInfo("formatDisk: diskoConfig = %s", diskoConfig)

	// Check if disko config exists
	if _, err := os.Stat(diskoConfig); os.IsNotExist(err) {
		return fmt.Errorf("disko config does not exist: %s", diskoConfig)
	}

	// Log disko config contents
	diskoContent, _ := os.ReadFile(diskoConfig)
	logInfo("formatDisk: disks.nix contents:\n%s", string(diskoContent))

	if c.StorageMode.isZFS() {
		logInfo("formatDisk: removing /etc/hostid")
		os.Remove("/etc/hostid")

		logInfo("formatDisk: running zgenhostid %s", c.HostID)
		if _, err := runCommand("zgenhostid", c.HostID); err != nil {
			return fmt.Errorf("zgenhostid: %w", err)
		}
	}

	// Unmount partitions on all target disks
	for _, disk := range c.Disks {
		logInfo("formatDisk: unmounting partitions on %s", disk)
		lsblkOutput, _ := runCommand("lsblk", "-nr", "-o", "NAME", disk)
		partitions := strings.Split(lsblkOutput, "\n")
		for i, part := range partitions {
			if i == 0 || part == "" {
				continue
			}
			partPath := "/dev/" + strings.TrimSpace(part)
			logInfo("formatDisk: unmounting %s", partPath)
			runCommand("umount", partPath)
		}
	}

	if c.StorageMode.isZFS() {
		logInfo("formatDisk: exporting all zpools")
		runCommand("zpool", "export", "-a")
	}

	logInfo("formatDisk: running disko --mode disko %s", diskoConfig)
	diskoCmd := exec.Command("disko", "--mode", "disko", diskoConfig)

	if c.StorageMode.isEncrypted() {
		// Pipe the passphrase to disko's stdin for ZFS encryption
		// ZFS prompts for passphrase twice (enter + confirm), so we send it twice
		logInfo("formatDisk: piping passphrase for ZFS encryption")
		passInput := c.Passphrase + "\n" + c.Passphrase + "\n"
		diskoCmd.Stdin = strings.NewReader(passInput)
	}

	var diskoOut, diskoErr bytes.Buffer
	diskoCmd.Stdout = &diskoOut
	diskoCmd.Stderr = &diskoErr
	if err := diskoCmd.Run(); err != nil {
		logError("formatDisk: disko failed: %v\nstdout: %s\nstderr: %s", err, diskoOut.String(), diskoErr.String())
		return fmt.Errorf("disko failed: %w", err)
	}
	logInfo("formatDisk: disko completed successfully")

	return nil
}

// generateMultiDiskDiskoConfig creates a disko configuration for multi-disk ZFS setups
func generateMultiDiskDiskoConfig(c Config) string {
	poolName := c.ZFSPoolName

	// Determine ZFS pool mode
	// In disko, mode = "" means stripe (no redundancy), "raidz" and "raidz2" for parity modes
	var zfsMode string
	switch c.StorageMode {
	case storageZFSStripe:
		zfsMode = `""`
	case storageZFSRaidz:
		zfsMode = `"raidz"`
	case storageZFSRaidz2:
		zfsMode = `"raidz2"`
	}

	// Generate disk entries - first disk gets ESP + ZFS, rest get ZFS only
	var diskEntries strings.Builder
	for i, disk := range c.Disks {
		name := fmt.Sprintf("disk%d", i)
		if i == 0 {
			// First disk: ESP boot partition + ZFS partition
			diskEntries.WriteString(fmt.Sprintf(`      %s = {
        type = "disk";
        device = "%s";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              type = "EF00";
              size = "%s";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            zfs = {
              size = "100%%";
              content = {
                type = "zfs";
                pool = "%s";
              };
            };
          };
        };
      };
`, name, disk, c.SpaceBoot, poolName))
		} else {
			// Additional disks: entire disk is ZFS
			diskEntries.WriteString(fmt.Sprintf(`      %s = {
        type = "disk";
        device = "%s";
        content = {
          type = "gpt";
          partitions = {
            zfs = {
              size = "100%%";
              content = {
                type = "zfs";
                pool = "%s";
              };
            };
          };
        };
      };
`, name, disk, poolName))
		}
	}

	return fmt.Sprintf(`# Disko configuration for tuinix - multi-disk ZFS (%s)
# Generated by tuinix installer

{ lib, ... }:
{
  disko.devices = {
    disk = {
%s    };

    zpool = {
      "%s" = {
        type = "zpool";
        mode = %s;
        options = {
          ashift = "12";
          autotrim = "on";
        };
        rootFsOptions = {
          compression = "zstd";
          acltype = "posixacl";
          xattr = "sa";
          relatime = "on";
          mountpoint = "none";
          encryption = "aes-256-gcm";
          keyformat = "passphrase";
          keylocation = "prompt";
          "com.sun:auto-snapshot" = "false";
        };

        datasets = {
          "root" = {
            type = "zfs_fs";
            mountpoint = "/";
            options = {
              "com.sun:auto-snapshot" = "false";
              mountpoint = "/";
            };
            postCreateHook = ''
              zfs snapshot %s/root@blank
            '';
          };

          "nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
            options = {
              "com.sun:auto-snapshot" = "false";
              quota = "%s";
            };
          };

          "home" = {
            type = "zfs_fs";
            mountpoint = "/home";
            options = { "com.sun:auto-snapshot" = "true"; };
          };

          "overflow" = {
            type = "zfs_fs";
            mountpoint = "/overflow";
            options = { "com.sun:auto-snapshot" = "true"; };
          };

          "atuin" = {
            type = "zfs_volume";
            size = "%s";
            content = {
              type = "filesystem";
              format = "xfs";
              mountpoint = "/var/atuin";
              mountOptions = [ "defaults" "nofail" ];
            };
          };
        };
      };
    };
  };
}
`, c.StorageMode, diskEntries.String(), poolName, zfsMode,
		poolName, c.SpaceNix, c.SpaceAtuin)
}

// hashPassword generates a SHA-512 crypt hash using mkpasswd
// detectDisplayResolution reads the current framebuffer resolution from sysfs.
// Returns a string like "1920x1080" or empty string if detection fails.
func detectDisplayResolution() string {
	// Try the primary framebuffer device
	data, err := os.ReadFile("/sys/class/graphics/fb0/virtual_size")
	if err != nil {
		logInfo("detectDisplayResolution: could not read fb0 virtual_size: %v", err)
		return ""
	}
	// Format is "W,H\n" (e.g. "1920,1080\n")
	parts := strings.Split(strings.TrimSpace(string(data)), ",")
	if len(parts) != 2 {
		logInfo("detectDisplayResolution: unexpected format: %s", string(data))
		return ""
	}
	res := parts[0] + "x" + parts[1]
	logInfo("detectDisplayResolution: detected %s", res)
	return res
}

func hashPassword(password string) (string, error) {
	cmd := exec.Command("mkpasswd", "-m", "sha-512", "--stdin")
	cmd.Stdin = strings.NewReader(password)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		logError("mkpasswd failed: %v, stderr: %s", err, stderr.String())
		return "", fmt.Errorf("mkpasswd failed: %w", err)
	}
	return strings.TrimSpace(stdout.String()), nil
}
