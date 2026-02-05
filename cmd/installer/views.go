package main

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"
)

func (m model) viewWizard() string {
	step, ok := wizardSteps[m.state]
	if !ok {
		return m.viewSplash()
	}

	// Header
	header := m.renderHeader()

	// Horizontal line
	line1 := m.renderHorizontalLine()

	// Step indicator
	stepInd := m.renderStepIndicator(step.stepNum)

	// Horizontal line
	line2 := m.renderHorizontalLine()

	// Content area - two columns
	leftWidth := m.width/2 - 4
	rightWidth := m.width/2 - 4
	contentHeight := m.height - 22 // Account for header, lines, step indicator, footer

	if contentHeight < 10 {
		contentHeight = 10
	}

	// Left column: title and description
	titleText := titleStyle.Width(leftWidth).Render(step.title)
	descText := lipgloss.NewStyle().Foreground(colorOffWhite).Width(leftWidth).Render(step.description)
	leftContent := lipgloss.JoinVertical(lipgloss.Left,
		titleText,
		"",
		descText,
	)

	// Apply spring animation offset to left box (slides in from left)
	leftOffset := int(m.leftX)
	if leftOffset < 0 {
		leftOffset = 0
	}
	leftBox := borderStyle.
		Width(leftWidth).
		Height(contentHeight).
		MarginLeft(leftOffset).
		Render(leftContent)

	// Right column: user inputs
	rightContent := m.renderRightPanel(step.stepNum)

	// Apply spring animation offset to right box (slides in from right)
	rightOffset := int(m.rightX)
	if rightOffset < 0 {
		rightOffset = 0
	}
	rightBox := borderStyle.
		Width(rightWidth).
		Height(contentHeight).
		MarginRight(rightOffset).
		Render(rightContent)

	// Combine columns
	contentArea := lipgloss.JoinHorizontal(lipgloss.Top,
		leftBox,
		"  ",
		rightBox,
	)

	// Footer
	footer := m.renderFooter()

	// Combine all
	fullView := lipgloss.JoinVertical(lipgloss.Center,
		header,
		line1,
		stepInd,
		line2,
		contentArea,
		footer,
	)

	return lipgloss.Place(m.width, m.height, lipgloss.Center, lipgloss.Center, fullView)
}

func (m model) viewFireTransition() string {
	grid := make([][]rune, m.height)
	colors := make([][]lipgloss.Color, m.height)
	for i := range grid {
		grid[i] = make([]rune, m.width)
		colors[i] = make([]lipgloss.Color, m.width)
		for j := range grid[i] {
			grid[i][j] = ' '
		}
	}

	fireColors := []lipgloss.Color{
		lipgloss.Color("#FFFFFF"),
		lipgloss.Color("#FFFF00"),
		lipgloss.Color("#FF8800"),
		lipgloss.Color("#E95420"),
		lipgloss.Color("#FF0000"),
		lipgloss.Color("#880000"),
	}

	for _, p := range m.fireParticles {
		if p.life > 0 {
			x := int(p.x)
			y := int(p.y)
			if x >= 0 && x < m.width && y >= 0 && y < m.height {
				grid[y][x] = p.char
				colorIdx := int((1 - p.life/p.maxLife) * float64(len(fireColors)-1))
				if colorIdx < 0 {
					colorIdx = 0
				}
				if colorIdx >= len(fireColors) {
					colorIdx = len(fireColors) - 1
				}
				colors[y][x] = fireColors[colorIdx]
			}
		}
	}

	var b strings.Builder
	for y := 0; y < m.height; y++ {
		for x := 0; x < m.width; x++ {
			if grid[y][x] != ' ' {
				style := lipgloss.NewStyle().Foreground(colors[y][x])
				b.WriteString(style.Render(string(grid[y][x])))
			} else {
				b.WriteRune(' ')
			}
		}
		if y < m.height-1 {
			b.WriteRune('\n')
		}
	}

	return b.String()
}

func (m model) viewSplash() string {
	// Large mascot logo (catimg output with embedded ANSI colors)
	largeLogo := strings.TrimRight(mascotLogoLarge, "\n ")

	// Center the logo by padding each line
	logoLines := strings.Split(largeLogo, "\n")
	centeredLogo := make([]string, len(logoLines))
	// catimg visual width is ~30 chars for w60
	logoVisualWidth := 30
	for i, line := range logoLines {
		pad := (m.width - logoVisualWidth) / 2
		if pad < 0 {
			pad = 0
		}
		centeredLogo[i] = strings.Repeat(" ", pad) + line
	}
	logoBlock := strings.Join(centeredLogo, "\n")

	// TUINIX title centered
	titleLines := strings.Split(tuinixTitle, "\n")
	styledTitle := make([]string, len(titleLines))
	for i, line := range titleLines {
		styledTitle[i] = headerTitleStyle.Render(line)
	}
	titleBlock := lipgloss.NewStyle().
		Align(lipgloss.Center).
		Width(m.width - 4).
		Render(strings.Join(styledTitle, "\n"))

	line := m.renderHorizontalLine()

	subtitle := lipgloss.NewStyle().
		Foreground(colorNixBlue).
		Align(lipgloss.Center).
		Width(m.width - 4).
		Render("Terminal-focused NixOS")

	version := detailStyle.Copy().
		Align(lipgloss.Center).
		Width(m.width - 4).
		Render("Installer v1.0")

	hint := grayStyle.Copy().
		Align(lipgloss.Center).
		Width(m.width - 4).
		Render("Starting installation wizard...")

	footer := m.renderFooter()

	content := lipgloss.JoinVertical(lipgloss.Center,
		logoBlock,
		"",
		titleBlock,
		line,
		"",
		subtitle,
		version,
		"",
		hint,
		"",
		footer,
	)

	return lipgloss.Place(m.width, m.height, lipgloss.Center, lipgloss.Center, content)
}

func (m model) viewGravityAnimation() string {
	grid := make([][]rune, m.height)
	colors := make([][]lipgloss.Color, m.height)
	for i := range grid {
		grid[i] = make([]rune, m.width)
		colors[i] = make([]lipgloss.Color, m.width)
		for j := range grid[i] {
			grid[i][j] = ' '
		}
	}

	for _, c := range m.physicsChars {
		x := int(c.x)
		y := int(c.y)
		if x >= 0 && x < m.width && y >= 0 && y < m.height {
			grid[y][x] = c.char
			colors[y][x] = c.color
		}
	}

	var b strings.Builder
	for y := 0; y < m.height; y++ {
		for x := 0; x < m.width; x++ {
			if grid[y][x] != ' ' {
				style := lipgloss.NewStyle().Foreground(colors[y][x])
				b.WriteString(style.Render(string(grid[y][x])))
			} else {
				b.WriteRune(' ')
			}
		}
		if y < m.height-1 {
			b.WriteRune('\n')
		}
	}

	return b.String()
}

func (m model) viewInstalling() string {
	header := m.renderHeader()
	line := m.renderHorizontalLine()

	title := titleStyle.Copy().
		Align(lipgloss.Center).
		Width(m.width - 4).
		Render("Installing tuinix")

	steps := m.getInstallStepNames()

	pendingStyle := lipgloss.NewStyle().Foreground(colorDimGray)
	activeStyle := lipgloss.NewStyle().Foreground(colorOffWhite).Bold(true)
	var stepList strings.Builder
	for i, step := range steps {
		var icon, text string
		if i < m.installStep {
			icon = successStyle.Render("[done] ")
			text = successStyle.Render(step)
		} else if i == m.installStep {
			spinChars := []string{"|", "/", "-", "\\"}
			spin := spinChars[m.animTick%len(spinChars)]
			icon = activeStyle.Render("[" + spin + "] ")
			text = activeStyle.Render(step + "...")
		} else {
			icon = pendingStyle.Render("[ ] ")
			text = pendingStyle.Render(step)
		}
		stepList.WriteString(icon + text + "\n")
	}

	var errText string
	if m.installErr != nil {
		errText = errorStyle.Render("\nError: " + m.installErr.Error())
	}

	// Log tail display - show last 3 lines from install log
	var logTailDisplay string
	if len(m.logTail) > 0 {
		logBox := lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(colorDarkGray).
			Foreground(colorDimGray).
			Width(m.width - 8).
			Padding(0, 1)
		var tailLines []string
		for _, l := range m.logTail {
			// Truncate long lines to fit the box
			if len(l) > m.width-12 {
				l = l[:m.width-12] + "..."
			}
			tailLines = append(tailLines, l)
		}
		logTailDisplay = logBox.Render(strings.Join(tailLines, "\n"))
	}

	progress := detailStyle.Copy().
		Align(lipgloss.Center).
		Width(m.width - 4).
		Render("This may take 10-30 minutes...")

	footer := m.renderFooter()

	content := lipgloss.JoinVertical(lipgloss.Center,
		header,
		line,
		"",
		title,
		"",
		stepList.String(),
		errText,
		"",
		logTailDisplay,
		"",
		progress,
		"",
		footer,
	)

	return lipgloss.Place(m.width, m.height, lipgloss.Center, lipgloss.Center, content)
}

func (m model) viewComplete() string {
	header := m.renderHeader()
	line := m.renderHorizontalLine()

	title := successStyle.Copy().
		Bold(true).
		Align(lipgloss.Center).
		Width(m.width - 4).
		Render("Installation Complete!")

	completeInfoStyle := lipgloss.NewStyle().Foreground(colorOffWhite)
	info := lipgloss.JoinVertical(lipgloss.Left,
		completeInfoStyle.Render("Your tuinix system is ready!"),
		"",
		completeInfoStyle.Render("Login credentials:"),
		completeInfoStyle.Render(fmt.Sprintf("  Username: %s", m.config.Username)),
		completeInfoStyle.Render("  Password: (the one you set during install)"),
		"",
		completeInfoStyle.Render("Your flake is at:"),
		completeInfoStyle.Render(fmt.Sprintf("  /home/%s/tuinix", m.config.Username)),
		"",
		completeInfoStyle.Render("Rebuild command:"),
		completeInfoStyle.Render(fmt.Sprintf("  sudo nixos-rebuild switch --flake .#%s", m.config.Hostname)),
		"",
		successStyle.Render("Git is pre-configured with your identity"),
	)

	reboot := promptStyle.Copy().
		Align(lipgloss.Center).
		Width(m.width - 4).
		Render("Remove installation media and reboot!")

	exitHint := grayStyle.Copy().
		Align(lipgloss.Center).
		Width(m.width - 4).
		Render("Press Enter or q to exit")

	footer := m.renderFooter()

	content := lipgloss.JoinVertical(lipgloss.Center,
		header,
		line,
		"",
		title,
		"",
		info,
		"",
		reboot,
		exitHint,
		"",
		footer,
	)

	return lipgloss.Place(m.width, m.height, lipgloss.Center, lipgloss.Center, content)
}

func (m model) viewError() string {
	header := m.renderHeader()
	line := m.renderHorizontalLine()

	title := errorStyle.Copy().
		Bold(true).
		Align(lipgloss.Center).
		Width(m.width - 4).
		Render("Installation Failed")

	errMsg := ""
	if m.installErr != nil {
		errMsg = m.installErr.Error()
	}

	errInfoStyle := lipgloss.NewStyle().Foreground(colorOffWhite)
	info := lipgloss.JoinVertical(lipgloss.Left,
		errInfoStyle.Render("An error occurred during installation:"),
		"",
		errorStyle.Render(errMsg),
		"",
		errInfoStyle.Bold(true).Render("Please check the error message above."),
		grayStyle.Render("You may need to reboot and try again."),
	)

	exitHint := grayStyle.Copy().
		Align(lipgloss.Center).
		Width(m.width - 4).
		Render("Press Enter or q to exit")

	footer := m.renderFooter()

	content := lipgloss.JoinVertical(lipgloss.Center,
		header,
		line,
		"",
		title,
		"",
		info,
		"",
		exitHint,
		"",
		footer,
	)

	return lipgloss.Place(m.width, m.height, lipgloss.Center, lipgloss.Center, content)
}

func (m model) viewNetworkCheck() string {
	header := m.renderHeader()
	line := m.renderHorizontalLine()

	title := titleStyle.Copy().
		Align(lipgloss.Center).
		Width(m.width - 4).
		Render("Network Connectivity")

	var status string
	if m.networkOk {
		status = successStyle.Render("Connected to the internet.")
		status += "\n\n" + grayStyle.Render("Press Enter to continue")
	} else {
		spinChars := []string{"|", "/", "-", "\\"}
		spin := spinChars[m.animTick%len(spinChars)]

		status = warningStyle.Render("["+spin+"] Checking network connectivity...")
		if m.animTick > 5 {
			// Check already returned failure
			status = errorStyle.Render("No internet connection detected.") +
				"\n\n" + lipgloss.NewStyle().Foreground(colorOffWhite).Render(
				"An internet connection is required during installation.\n"+
					"Press q to exit the installer, then configure your network:\n\n"+
					"  Wired:  Should connect automatically via DHCP\n"+
					"  WiFi:   Use wpa_cli or iwctl to connect\n\n"+
					"Then run sudo installer again.") +
				"\n\n" + grayStyle.Render("Press Enter to retry | q to exit")
		}
	}

	footer := m.renderFooter()

	content := lipgloss.JoinVertical(lipgloss.Center,
		header,
		line,
		"",
		title,
		"",
		status,
		"",
		footer,
	)

	return lipgloss.Place(m.width, m.height, lipgloss.Center, lipgloss.Center, content)
}
