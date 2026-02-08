package main

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"
)

// renderHeader creates the consistent header with logo and title
func (m model) renderHeader() string {
	// Left side: mascot logo (catimg output already has embedded ANSI colors)
	logoBlock := strings.TrimRight(mascotLogo, "\n ")

	// Right side: TUINIX title
	titleLines := strings.Split(tuinixTitle, "\n")
	styledTitle := make([]string, len(titleLines))
	for i, line := range titleLines {
		styledTitle[i] = headerTitleStyle.Render(line)
	}
	titleBlock := strings.Join(styledTitle, "\n")

	// Calculate widths
	logoWidth := lipgloss.Width(logoBlock)
	titleWidth := lipgloss.Width(titleBlock)
	gap := m.width - logoWidth - titleWidth - 4

	if gap < 2 {
		gap = 2
	}

	// Combine horizontally
	logoStyle := lipgloss.NewStyle().Width(logoWidth)
	titleStyle := lipgloss.NewStyle().Width(titleWidth)
	gapStyle := lipgloss.NewStyle().Width(gap)

	header := lipgloss.JoinHorizontal(lipgloss.Top,
		logoStyle.Render(logoBlock),
		gapStyle.Render(""),
		titleStyle.Render(titleBlock),
	)

	return header
}

// renderStepIndicator shows current step
func (m model) renderStepIndicator(stepNum int) string {
	indicator := fmt.Sprintf("━━━ Step %d of %d ━━━", stepNum, totalSteps)
	return stepStyle.Width(m.width - 4).Render(indicator)
}

// renderFooter creates the footer with horizontal line, version, URL, and Kartoza branding
func (m model) renderFooter() string {
	line := strings.Repeat("─", m.width-4)
	version := strings.TrimSpace(versionInfo)
	url := "https://github.com/timlinux/tuinix"
	footerText := fmt.Sprintf("%s  |  %s", version, url)
	kartoza := lipgloss.NewStyle().Foreground(colorOrange).Render("Made with \u2764 by Kartoza") +
		grayStyle.Render("  |  https://kartoza.com  |  Donate: https://github.com/sponsors/timlinux")
	return lipgloss.JoinVertical(lipgloss.Center,
		grayStyle.Render(line),
		footerStyle.Width(m.width-4).Render(footerText),
		footerStyle.Width(m.width-4).Render(kartoza),
	)
}

// renderHorizontalLine creates a horizontal separator
func (m model) renderHorizontalLine() string {
	return grayStyle.Render(strings.Repeat("─", m.width-4))
}

func (m model) renderRightPanel(stepNum int) string {
	var content string

	switch m.state {
	case stateUsername, stateFullname, stateEmail, statePassword, statePasswordConfirm, stateHostname, statePassphrase, statePassphraseConfirm, stateGitHubUser, stateConfirm:
		inputBox := lipgloss.NewStyle().
			Border(lipgloss.NormalBorder()).
			BorderForeground(colorBlue).
			Padding(0, 1).
			Render(m.input.View())

		var errText string
		if m.err != nil {
			errText = "\n" + errorStyle.Render("! "+m.err.Error())
		}

		hint := grayStyle.Render("\nEnter to continue | Ctrl+C to quit")
		content = inputBox + errText + hint

	case stateStorageMode:
		var modeList strings.Builder
		for i, mode := range storageModes {
			cursor := "  "
			style := lipgloss.NewStyle().Foreground(colorOffWhite)
			if i == m.selectedIdx {
				cursor = "> "
				style = style.Foreground(colorOrange).Bold(true)
			}
			modeList.WriteString(style.Render(cursor + mode.String()))
			modeList.WriteString("\n")
			modeList.WriteString(grayStyle.Render("   " + storageModeDescriptions[mode]))
			modeList.WriteString("\n")
		}
		hint := grayStyle.Render("\nUp/Down to select | Enter to confirm")
		content = modeList.String() + hint

	case stateDisk:
		var diskList strings.Builder
		for i, disk := range m.disks {
			cursor := "  "
			style := lipgloss.NewStyle().Foreground(colorOffWhite)
			if i == m.selectedIdx {
				cursor = "> "
				style = style.Foreground(colorOrange).Bold(true)
			}
			line := fmt.Sprintf("%s%-10s %8s", cursor, disk.Path, disk.Size)
			diskList.WriteString(style.Render(line))
			diskList.WriteString("\n")
			if disk.Model != "" {
				diskList.WriteString(grayStyle.Render("   " + disk.Model))
				diskList.WriteString("\n")
			}
		}

		warning := errorStyle.Render("! ALL DATA WILL BE DESTROYED!")
		hint := grayStyle.Render("\nUp/Down to select | Enter to confirm")
		content = warning + "\n\n" + diskList.String() + hint

	case statePartitionBoot:
		var partList strings.Builder
		for i, part := range m.partitions {
			cursor := "  "
			style := lipgloss.NewStyle().Foreground(colorOffWhite)
			if i == m.selectedIdx {
				cursor = "> "
				style = style.Foreground(colorOrange).Bold(true)
			}
			line := fmt.Sprintf("%s%-12s %8s  %s", cursor, part.Path, part.Size, part.FSType)
			partList.WriteString(style.Render(line))
			partList.WriteString("\n")
			if part.Label != "" {
				partList.WriteString(grayStyle.Render("   " + part.Label))
				partList.WriteString("\n")
			}
		}

		note := grayStyle.Render("Select the EFI/boot partition (typically vfat)")
		hint := grayStyle.Render("\nUp/Down to select | Enter to confirm")
		content = note + "\n\n" + partList.String() + hint

	case statePartitionRoot:
		var partList strings.Builder
		for i, part := range m.partitions {
			cursor := "  "
			style := lipgloss.NewStyle().Foreground(colorOffWhite)
			if i == m.selectedIdx {
				cursor = "> "
				style = style.Foreground(colorOrange).Bold(true)
			}
			// Indicate which partition is already selected as boot
			bootMarker := ""
			if part.Path == m.config.BootPartition {
				bootMarker = " [boot]"
			}
			line := fmt.Sprintf("%s%-12s %8s  %s%s", cursor, part.Path, part.Size, part.FSType, bootMarker)
			partList.WriteString(style.Render(line))
			partList.WriteString("\n")
			if part.Label != "" {
				partList.WriteString(grayStyle.Render("   " + part.Label))
				partList.WriteString("\n")
			}
		}

		warning := errorStyle.Render("! This partition will be formatted with XFS!")
		var errText string
		if m.err != nil {
			errText = "\n" + errorStyle.Render("! "+m.err.Error())
		}
		hint := grayStyle.Render("\nUp/Down to select | Enter to confirm")
		content = warning + "\n\n" + partList.String() + errText + hint

	case stateDiskMulti:
		var diskList strings.Builder
		selectedCount := 0
		for i, disk := range m.disks {
			cursor := "  "
			check := "[ ]"
			style := lipgloss.NewStyle().Foreground(colorOffWhite)
			if i == m.selectedIdx {
				cursor = "> "
				style = style.Foreground(colorOrange).Bold(true)
			}
			if m.diskSelected[i] {
				check = "[x]"
				selectedCount++
			}
			line := fmt.Sprintf("%s%s %-10s %8s", cursor, check, disk.Path, disk.Size)
			diskList.WriteString(style.Render(line))
			diskList.WriteString("\n")
			if disk.Model != "" {
				diskList.WriteString(grayStyle.Render("      " + disk.Model))
				diskList.WriteString("\n")
			}
		}

		minDisks := m.config.StorageMode.minDisks()
		status := fmt.Sprintf("Selected: %d (min %d)", selectedCount, minDisks)
		statusStyle := lipgloss.NewStyle().Foreground(colorDimGray)
		if selectedCount >= minDisks {
			statusStyle = statusStyle.Foreground(colorGreen)
		}

		warning := errorStyle.Render("! ALL SELECTED DISKS WILL BE DESTROYED!")
		var errText string
		if m.err != nil {
			errText = "\n" + errorStyle.Render("! "+m.err.Error())
		}
		hint := grayStyle.Render("\nSpace to toggle | Up/Down to move | Enter to confirm")
		content = warning + "\n" + statusStyle.Render(status) + "\n\n" + diskList.String() + errText + hint

	case stateSSH:
		sshOptions := []struct {
			label string
			desc  string
		}{
			{"Yes - Enable SSH", "SSH server on port 22, firewall enabled"},
			{"No - Disable SSH", "No remote access (can enable later)"},
		}
		var optList strings.Builder
		for i, opt := range sshOptions {
			cursor := "  "
			style := lipgloss.NewStyle().Foreground(colorOffWhite)
			if i == m.selectedIdx {
				cursor = "> "
				style = style.Foreground(colorOrange).Bold(true)
			}
			optList.WriteString(style.Render(cursor + opt.label))
			optList.WriteString("\n")
			optList.WriteString(grayStyle.Render("   " + opt.desc))
			optList.WriteString("\n")
		}
		hint := grayStyle.Render("\nUp/Down to select | Enter to confirm")
		content = optList.String() + hint

	case stateLocale:
		var optList strings.Builder
		for i, opt := range m.locales {
			cursor := "  "
			style := lipgloss.NewStyle().Foreground(colorOffWhite)
			if i == m.selectedIdx {
				cursor = "> "
				style = style.Foreground(colorOrange).Bold(true)
			}
			optList.WriteString(style.Render(cursor + opt))
			optList.WriteString("\n")
		}
		hint := grayStyle.Render("\nUp/Down to select | Enter to confirm")
		content = optList.String() + hint

	case stateKeymap:
		var optList strings.Builder
		for i, km := range m.keymaps {
			cursor := "  "
			style := lipgloss.NewStyle().Foreground(colorOffWhite)
			if i == m.selectedIdx {
				cursor = "> "
				style = style.Foreground(colorOrange).Bold(true)
			}
			optList.WriteString(style.Render(cursor + km.Label))
			optList.WriteString("\n")
		}
		hint := grayStyle.Render("\nUp/Down to select | Enter to confirm")
		content = optList.String() + hint

	case stateSummary:
		infoStyle := lipgloss.NewStyle().Foreground(colorOffWhite)

		// Build disk info section
		var diskInfo string
		if m.config.StorageMode.usesPartitions() {
			diskInfo = infoStyle.Render(fmt.Sprintf("  Disk:      %s", m.config.Disk)) + "\n" +
				infoStyle.Render(fmt.Sprintf("  Boot part: %s", m.config.BootPartition)) + "\n" +
				infoStyle.Render(fmt.Sprintf("  Root part: %s", m.config.RootPartition))
		} else if m.config.StorageMode.isMultiDisk() {
			diskInfo = infoStyle.Render(fmt.Sprintf("  Disks:     %s", strings.Join(m.config.Disks, ", ")))
		} else {
			diskInfo = infoStyle.Render(fmt.Sprintf("  Disk:      %s", m.config.Disk))
		}

		// Build storage allocation section
		var allocSection string
		if m.config.StorageMode.usesPartitions() {
			allocSection = promptStyle.Render("Partition Layout") + "\n" +
				infoStyle.Render(fmt.Sprintf("  /boot:      %s (existing)", m.config.BootPartition)) + "\n" +
				infoStyle.Render(fmt.Sprintf("  /:          %s (XFS)", m.config.RootPartition))
		} else if m.config.StorageMode.isZFS() {
			allocSection = promptStyle.Render("Disk Allocation") + "\n" +
				infoStyle.Render(fmt.Sprintf("  /boot:      %s", m.config.SpaceBoot)) + "\n" +
				infoStyle.Render(fmt.Sprintf("  /nix:       %s", m.config.SpaceNix)) + "\n" +
				infoStyle.Render(fmt.Sprintf("  /home:      remainder"))
		} else {
			allocSection = promptStyle.Render("Disk Allocation") + "\n" +
				infoStyle.Render(fmt.Sprintf("  /boot:      %s", m.config.SpaceBoot)) + "\n" +
				infoStyle.Render("  /:          remainder (XFS)")
		}

		sshStatus := "Disabled"
		var sshExtra string
		if m.config.EnableSSH {
			sshStatus = "Enabled (port 22)"
			sshExtra = "\n" +
				infoStyle.Render(fmt.Sprintf("  GitHub:    %s", m.config.GitHubUser)) + "\n" +
				infoStyle.Render(fmt.Sprintf("  SSH keys:  %d key(s) imported", len(m.config.SSHKeys)))
		}

		content = promptStyle.Render("User Account") + "\n" +
			infoStyle.Render(fmt.Sprintf("  Username:  %s", m.config.Username)) + "\n" +
			infoStyle.Render(fmt.Sprintf("  Full name: %s", m.config.Fullname)) + "\n" +
			infoStyle.Render(fmt.Sprintf("  Email:     %s", m.config.Email)) + "\n\n" +
			promptStyle.Render("System") + "\n" +
			infoStyle.Render(fmt.Sprintf("  Hostname:  %s", m.config.Hostname)) + "\n" +
			infoStyle.Render(fmt.Sprintf("  Storage:   %s", m.config.StorageMode)) + "\n" +
			diskInfo + "\n" +
			infoStyle.Render(fmt.Sprintf("  Host ID:   %s", m.config.HostID)) + "\n" +
			infoStyle.Render(fmt.Sprintf("  Locale:    %s", m.config.Locale)) + "\n" +
			infoStyle.Render(fmt.Sprintf("  Keyboard:  %s", m.config.Keymap)) + "\n" +
			infoStyle.Render(fmt.Sprintf("  SSH:       %s", sshStatus)) +
			sshExtra + "\n\n" +
			allocSection + "\n\n" +
			grayStyle.Render("Enter to proceed | Ctrl+C to cancel")
	}

	return content
}

func (m model) getInstallStepNames() []string {
	if m.config.StorageMode.isZFS() {
		return []string{
			"Generating host configuration",
			"Formatting disk(s) with ZFS",
			"Generating hardware configuration",
			"Installing NixOS",
			"Configuring ZFS boot",
			"Setting up user flake",
			"Copying install log",
			"Finalizing ZFS pool",
		}
	}
	if m.config.StorageMode.usesPartitions() {
		return []string{
			"Generating host configuration",
			"Formatting root partition with XFS",
			"Generating hardware configuration",
			"Installing NixOS",
			"Copying flake to new system",
			"Setting up user flake",
			"Copying install log",
		}
	}
	return []string{
		"Generating host configuration",
		"Formatting disk with XFS",
		"Generating hardware configuration",
		"Installing NixOS",
		"Setting up user flake",
		"Copying install log",
	}
}
