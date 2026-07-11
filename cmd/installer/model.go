package main

import (
	"fmt"
	"math"
	"math/rand"
	"os"
	"path/filepath"
	"strings"

	"github.com/charmbracelet/bubbles/textinput"
	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"golang.org/x/term"
)

func initialModel() model {
	ti := textinput.New()
	ti.Focus()
	ti.CharLimit = 64
	ti.Width = 40

	vp := viewport.New(40, 10)

	// Find project root
	projectRoot := findProjectRoot()

	m := model{
		state:    stateFireTransition,
		input:    ti,
		viewport: vp,
		locales:  []string{"en_US.UTF-8", "en_GB.UTF-8", "pt_PT.UTF-8", "pt_BR.UTF-8", "de_DE.UTF-8", "fr_FR.UTF-8", "es_ES.UTF-8"},
		keymaps: []keymapEntry{
			{Label: "us", XKBLayout: "us", ConsoleMap: "us"},
			{Label: "uk", XKBLayout: "gb", ConsoleMap: "uk"},
			{Label: "pt", XKBLayout: "pt", ConsoleMap: "pt-latin1"},
			{Label: "br", XKBLayout: "br", ConsoleMap: "br-abnt2"},
			{Label: "de", XKBLayout: "de", ConsoleMap: "de-latin1"},
			{Label: "fr", XKBLayout: "fr", ConsoleMap: "fr-latin1"},
			{Label: "es", XKBLayout: "es", ConsoleMap: "es"},
		},
		pkgSelected: make([]bool, len(packageOptions)),
		config: Config{
			ZFSPoolName: "NIXROOT",
			SpaceBoot:   "5G",
			DisplayRes:  detectDisplayResolution(),
			ProjectRoot: projectRoot,
			WorkDir:     "/tmp/tuinix-install",
		},
	}

	// Get terminal size
	w, h, _ := term.GetSize(int(os.Stdout.Fd()))
	if w == 0 {
		w = 80
	}
	if h == 0 {
		h = 24
	}
	m.width = w
	m.height = h

	// Initialize fire particles
	m.initFireParticles()

	return m
}

func findProjectRoot() string {
	locations := []string{
		"/home/tuinix",
		"/iso/tuinix",
		"/etc/tuinix",
		".",
	}

	for _, loc := range locations {
		if _, err := os.Stat(filepath.Join(loc, "flake.nix")); err == nil {
			return loc
		}
	}
	return "/home/tuinix"
}

func (m model) Init() tea.Cmd {
	return tea.Batch(
		textinput.Blink,
		tea.EnterAltScreen,
		tick(),
	)
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmd tea.Cmd
	var cmds []tea.Cmd

	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c":
			return m, tea.Quit
		case "q":
			// Only allow q to quit on non-input screens (splash, disk selection, locale, keymap, ssh, summary, complete, error)
			// Text input states must pass q through to the input field
			switch m.state {
			case stateSplash, stateNetworkCheck, stateDisk, stateDiskMulti, statePartitionBoot, statePartitionRoot, stateLocale, stateKeymap, statePackageSet, stateSSH, stateSummary, stateStorageMode, stateComplete, stateError:
				return m, tea.Quit
			}
		case "tab", "shift+tab":
			// Cycle focus: content -> back button -> next button -> content
			if _, isWizard := wizardSteps[m.state]; isWizard {
				if msg.String() == "tab" {
					m.focusZone = (m.focusZone + 1) % 3
				} else {
					m.focusZone = (m.focusZone + 2) % 3
				}
				if m.focusZone == 0 {
					m.input.Focus()
				} else {
					m.input.Blur()
				}
				return m, nil
			}
		case "enter":
			if m.state != stateFireTransition && m.state != stateGravityOut && m.state != stateSplash {
				if _, isWizard := wizardSteps[m.state]; isWizard && m.focusZone == 1 {
					return m.handleBack()
				}
				prevState := m.state
				newModel, cmd := m.handleEnter()
				if nm, ok := newModel.(model); ok {
					if _, wasWizard := wizardSteps[prevState]; wasWizard && nm.state != prevState {
						nm.history = append(nm.history, prevState)
					}
					nm.focusZone = 0
					nm.input.Focus()
					return nm, cmd
				}
				return newModel, cmd
			}
		case " ":
			if m.state == stateDiskMulti && m.selectedIdx < len(m.disks) {
				m.diskSelected[m.selectedIdx] = !m.diskSelected[m.selectedIdx]
			} else if m.state == statePackageSet && m.selectedIdx < len(m.pkgSelected) {
				m.pkgSelected[m.selectedIdx] = !m.pkgSelected[m.selectedIdx]
			}
		case "up", "k":
			if m.state == stateDisk || m.state == stateDiskMulti || m.state == statePartitionBoot || m.state == statePartitionRoot || m.state == stateLocale || m.state == stateKeymap || m.state == statePackageSet || m.state == stateSSH || m.state == stateStorageMode {
				if m.selectedIdx > 0 {
					m.selectedIdx--
				}
			}
		case "down", "j":
			if m.state == stateDisk && m.selectedIdx < len(m.disks)-1 {
				m.selectedIdx++
			} else if m.state == stateDiskMulti && m.selectedIdx < len(m.disks)-1 {
				m.selectedIdx++
			} else if m.state == statePartitionBoot && m.selectedIdx < len(m.partitions)-1 {
				m.selectedIdx++
			} else if m.state == statePartitionRoot && m.selectedIdx < len(m.partitions)-1 {
				m.selectedIdx++
			} else if m.state == stateLocale && m.selectedIdx < len(m.locales)-1 {
				m.selectedIdx++
			} else if m.state == stateKeymap && m.selectedIdx < len(m.keymaps)-1 {
				m.selectedIdx++
			} else if m.state == statePackageSet && m.selectedIdx < len(packageOptions)-1 {
				m.selectedIdx++
			} else if m.state == stateSSH && m.selectedIdx < 1 {
				m.selectedIdx++
			} else if m.state == stateStorageMode && m.selectedIdx < len(storageModes)-1 {
				m.selectedIdx++
			}
		}

	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m.viewport.Width = msg.Width/2 - 6
		m.viewport.Height = msg.Height - 18

	case tickMsg:
		return m.handleTick()

	case installStepMsg:
		m.installLog = append(m.installLog, msg.msg)
		m.installStep = msg.step
		return m, nil

	case installDoneMsg:
		m.state = stateComplete
		return m, nil

	case installErrMsg:
		m.installErr = msg.err
		m.state = stateError
		return m, nil

	case networkCheckMsg:
		m.networkOk = msg.ok
		if msg.ok {
			m.state = stateUsername
			m.input.Placeholder = "e.g., john, alice"
			m.input.SetValue("")
		}
		return m, tick()

	case logTailMsg:
		m.logTail = msg.lines
		if msg.currentStep >= 0 {
			m.installStep = msg.currentStep
		}
		if m.state == stateInstalling {
			return m, pollLogTail(m.config.StorageMode.isZFS())
		}
		return m, nil
	}

	// Update text input for input states
	if m.state == stateUsername || m.state == stateFullname ||
		m.state == stateEmail || m.state == statePassword || m.state == statePasswordConfirm ||
		m.state == stateHostname ||
		m.state == statePassphrase || m.state == statePassphraseConfirm ||
		m.state == stateGitHubUser ||
		m.state == stateConfirm ||
		m.state == stateStorageMode || m.state == stateDiskMulti {
		m.input, cmd = m.input.Update(msg)
		cmds = append(cmds, cmd)
	}

	// Update viewport for scrollable description
	m.viewport, cmd = m.viewport.Update(msg)
	cmds = append(cmds, cmd)

	return m, tea.Batch(cmds...)
}

func (m model) handleTick() (tea.Model, tea.Cmd) {
	m.animTick++

	switch m.state {
	case stateFireTransition:
		allDead := true
		for i := range m.fireParticles {
			p := &m.fireParticles[i]
			p.x += p.vx
			p.y += p.vy
			p.vy += 0.05
			p.life--

			if p.life <= 0 || p.y < 0 {
				if m.animTick < 60 {
					m.fireParticles[i] = m.newFireParticle()
					allDead = false
				}
			} else {
				allDead = false
			}
		}

		if m.animTick > 80 || allDead {
			m.state = stateSplash
			m.animTick = 0
		}
		return m, tick()

	case stateSplash:
		if m.animTick > 60 {
			m.prevContent = m.viewSplash()
			m.initGravityChars(m.prevContent)
			m.nextState = stateNetworkCheck
			m.state = stateGravityOut
			m.animTick = 0
			m.input.Placeholder = "e.g., john, alice"
			m.input.SetValue("")
		}
		return m, tick()

	case stateGravityOut:
		allSettled := true
		for i := range m.physicsChars {
			c := &m.physicsChars[i]
			if !c.settled {
				allSettled = false
				c.vy += 0.8
				c.y += c.vy
				c.x += c.vx

				if c.y >= c.targetY {
					c.y = c.targetY
					c.vy = -c.vy * 0.6
					c.bounceCount++
					c.vx = (rand.Float64() - 0.5) * 2

					if c.bounceCount >= 3 && math.Abs(c.vy) < 1 {
						c.settled = true
					}
				}
			}
		}

		if allSettled || m.animTick > 100 {
			for i := range m.physicsChars {
				m.physicsChars[i].vy = -15 - rand.Float64()*5
				m.physicsChars[i].settled = false
			}
			m.animTick = 0
			m.state = m.nextState
		}
		return m, tick()

	case stateNetworkCheck:
		if m.animTick == 1 {
			return m, checkNetwork()
		}
		return m, tick()

	case stateInstalling:
		return m, tea.Batch(tick(), pollLogTail(m.config.StorageMode.isZFS()))

	default:
	}

	return m, nil
}

// handleBack returns to the previously visited wizard step (the Previous
// button). On the first step the button acts as Cancel and quits.
func (m model) handleBack() (tea.Model, tea.Cmd) {
	if len(m.history) == 0 {
		return m, tea.Quit
	}
	m.state = m.history[len(m.history)-1]
	m.history = m.history[:len(m.history)-1]
	m.err = nil
	m.focusZone = 0
	m.prepareStateInput()
	m.input.Focus()
	return m, nil
}

// prepareStateInput restores the text input and selection state for the
// step we navigate back to. Values already captured in the config are
// offered again for editing; secrets are always re-entered.
func (m *model) prepareStateInput() {
	m.input.EchoMode = textinput.EchoNormal
	m.input.EchoCharacter = 0
	m.input.SetValue("")
	m.selectedIdx = 0

	switch m.state {
	case stateUsername:
		m.input.Placeholder = "e.g., john, alice"
		m.input.SetValue(m.config.Username)
	case stateFullname:
		m.input.Placeholder = "e.g., John Smith"
		m.input.SetValue(m.config.Fullname)
	case stateEmail:
		m.input.Placeholder = "e.g., john@example.com"
		m.input.SetValue(m.config.Email)
	case statePassword:
		m.input.Placeholder = "Enter account password"
		m.input.EchoMode = textinput.EchoPassword
		m.input.EchoCharacter = '*'
	case statePasswordConfirm:
		m.input.Placeholder = "Re-enter password to confirm"
		m.input.EchoMode = textinput.EchoPassword
		m.input.EchoCharacter = '*'
	case stateHostname:
		m.input.Placeholder = "e.g., laptop, desktop, server"
		m.input.SetValue(m.config.Hostname)
	case statePassphrase:
		m.input.Placeholder = "Enter ZFS encryption passphrase"
		m.input.EchoMode = textinput.EchoPassword
		m.input.EchoCharacter = '*'
	case statePassphraseConfirm:
		m.input.Placeholder = "Re-enter passphrase to confirm"
		m.input.EchoMode = textinput.EchoPassword
		m.input.EchoCharacter = '*'
	case stateGitHubUser:
		m.input.Placeholder = "e.g., octocat"
		m.input.SetValue(m.config.GitHubUser)
	case stateConfirm:
		m.input.Placeholder = "Type DESTROY to confirm"
	}
}

func (m model) handleEnter() (tea.Model, tea.Cmd) {
	switch m.state {
	case stateNetworkCheck:
		if m.networkOk {
			m.state = stateUsername
			m.input.Placeholder = "e.g., john, alice"
			m.input.SetValue("")
			return m, nil
		}
		// Retry network check
		m.animTick = 0
		return m, tick()

	case stateUsername:
		val := strings.TrimSpace(m.input.Value())
		if !isValidUsername(val) {
			m.err = fmt.Errorf("invalid username: use lowercase letters, numbers, underscores, hyphens")
			return m, nil
		}
		m.config.Username = val
		m.err = nil
		m.state = stateFullname
		m.input.SetValue("")
		m.input.Placeholder = "e.g., John Smith"

	case stateFullname:
		val := strings.TrimSpace(m.input.Value())
		if val == "" {
			m.err = fmt.Errorf("full name is required")
			return m, nil
		}
		m.config.Fullname = val
		m.err = nil
		m.state = stateEmail
		m.input.SetValue("")
		m.input.Placeholder = "e.g., john@example.com"

	case stateEmail:
		val := strings.TrimSpace(m.input.Value())
		if !isValidEmail(val) {
			m.err = fmt.Errorf("please enter a valid email address")
			return m, nil
		}
		m.config.Email = val
		m.err = nil
		m.state = statePassword
		m.input.SetValue("")
		m.input.Placeholder = "Enter account password"
		m.input.EchoMode = textinput.EchoPassword
		m.input.EchoCharacter = '*'

	case statePassword:
		val := m.input.Value()
		if len(val) < 8 {
			m.err = fmt.Errorf("password must be at least 8 characters")
			return m, nil
		}
		m.config.Password = val // pragma: allowlist secret
		m.err = nil
		m.state = statePasswordConfirm
		m.input.SetValue("")
		m.input.Placeholder = "Re-enter password to confirm"

	case statePasswordConfirm:
		val := m.input.Value()
		if val != m.config.Password {
			m.err = fmt.Errorf("passwords do not match")
			m.input.SetValue("")
			return m, nil
		}
		m.err = nil
		m.state = stateHostname
		m.input.SetValue("")
		m.input.EchoMode = textinput.EchoNormal
		m.input.EchoCharacter = 0
		m.input.Placeholder = "e.g., laptop, desktop, server"

	case stateHostname:
		val := strings.TrimSpace(m.input.Value())
		if !isValidHostname(val) {
			m.err = fmt.Errorf("invalid hostname: use letters, numbers, and hyphens only")
			return m, nil
		}
		m.config.Hostname = val
		m.err = nil
		m.state = stateStorageMode
		m.selectedIdx = 0

	case stateStorageMode:
		mode := storageModes[m.selectedIdx]
		m.config.StorageMode = mode
		m.disks = getAvailableDisks()
		m.selectedIdx = 0
		m.err = nil
		if mode.isMultiDisk() {
			if len(m.disks) < mode.minDisks() {
				m.err = fmt.Errorf("%s requires at least %d disks, but only %d found", mode, mode.minDisks(), len(m.disks))
				return m, nil
			}
			m.diskSelected = make([]bool, len(m.disks))
			m.state = stateDiskMulti
		} else {
			m.state = stateDisk
		}

	case stateDisk:
		if len(m.disks) > 0 {
			m.config.Disk = m.disks[m.selectedIdx].Path
			m.config.Disks = []string{m.config.Disk}
			m.config.HostID = generateHostID()
			if m.config.StorageMode.usesPartitions() {
				// Partition mode: load partitions from selected disk, go to boot partition selection
				m.partitions = getAvailablePartitions(m.config.Disk)
				m.selectedIdx = 0
				m.state = statePartitionBoot
			} else if m.config.StorageMode.isEncrypted() {
				m.state = statePassphrase
				m.input.SetValue("")
				m.input.Placeholder = "Enter ZFS encryption passphrase"
				m.input.EchoMode = textinput.EchoPassword
				m.input.EchoCharacter = '*'
			} else {
				// XFS whole-disk mode: skip passphrase, go to locale
				m.state = stateLocale
				m.input.SetValue("")
				m.input.EchoMode = textinput.EchoNormal
				m.input.EchoCharacter = 0
				m.selectedIdx = 0
			}
		}

	case statePartitionBoot:
		if len(m.partitions) > 0 {
			m.config.BootPartition = m.partitions[m.selectedIdx].Path
			m.err = nil
			m.selectedIdx = 0
			m.state = statePartitionRoot
		}

	case statePartitionRoot:
		if len(m.partitions) > 0 {
			selected := m.partitions[m.selectedIdx]
			if selected.Path == m.config.BootPartition {
				m.err = fmt.Errorf("root partition must be different from boot partition (%s)", m.config.BootPartition)
				return m, nil
			}
			m.config.RootPartition = selected.Path
			m.err = nil
			m.state = stateLocale
			m.input.SetValue("")
			m.input.EchoMode = textinput.EchoNormal
			m.input.EchoCharacter = 0
			m.selectedIdx = 0
		}

	case stateDiskMulti:
		var selectedDisks []string
		for i, sel := range m.diskSelected {
			if sel {
				selectedDisks = append(selectedDisks, m.disks[i].Path)
			}
		}
		minRequired := m.config.StorageMode.minDisks()
		if len(selectedDisks) < minRequired {
			m.err = fmt.Errorf("select at least %d disks for %s", minRequired, m.config.StorageMode)
			return m, nil
		}
		m.config.Disks = selectedDisks
		m.config.Disk = selectedDisks[0] // First disk is the boot disk
		m.config.HostID = generateHostID()
		m.err = nil
		// Multi-disk modes are always encrypted ZFS
		m.state = statePassphrase
		m.input.SetValue("")
		m.input.Placeholder = "Enter ZFS encryption passphrase"
		m.input.EchoMode = textinput.EchoPassword
		m.input.EchoCharacter = '*'

	case statePassphrase:
		val := m.input.Value()
		if len(val) < 8 {
			m.err = fmt.Errorf("passphrase must be at least 8 characters")
			return m, nil
		}
		m.config.Passphrase = val
		m.err = nil
		m.state = statePassphraseConfirm
		m.input.SetValue("")
		m.input.Placeholder = "Re-enter passphrase to confirm"

	case statePassphraseConfirm:
		val := m.input.Value()
		if val != m.config.Passphrase {
			m.err = fmt.Errorf("passphrases do not match")
			m.input.SetValue("")
			return m, nil
		}
		m.err = nil
		m.state = stateLocale
		m.input.SetValue("")
		m.input.EchoMode = textinput.EchoNormal
		m.input.EchoCharacter = 0
		m.selectedIdx = 0

	case stateLocale:
		m.config.Locale = m.locales[m.selectedIdx]
		m.state = stateKeymap
		m.selectedIdx = 0

	case stateKeymap:
		km := m.keymaps[m.selectedIdx]
		m.config.Keymap = km.XKBLayout
		m.config.ConsoleKeyMap = km.ConsoleMap
		calculateSpaceAllocation(&m.config)
		m.state = statePackageSet
		m.selectedIdx = 0

	case statePackageSet:
		m.config.EnableTUI = m.pkgSelected[0]
		m.config.EnablePentest = m.pkgSelected[1]
		m.config.EnableGames = m.pkgSelected[2]
		m.config.EnableMusic = m.pkgSelected[3]
		m.config.EnableEmergency = m.pkgSelected[4]
		m.state = stateSSH
		m.selectedIdx = 0

	case stateSSH:
		m.config.EnableSSH = m.selectedIdx == 0
		if m.config.EnableSSH {
			m.state = stateGitHubUser
			m.input.SetValue("")
			m.input.Placeholder = "e.g., octocat"
			m.input.EchoMode = textinput.EchoNormal
			m.input.EchoCharacter = 0
		} else {
			m.state = stateSummary
		}

	case stateGitHubUser:
		val := strings.TrimSpace(m.input.Value())
		if val == "" {
			m.err = fmt.Errorf("GitHub username is required for SSH key setup")
			return m, nil
		}
		// Fetch SSH keys from GitHub
		keys, err := fetchGitHubKeys(val)
		if err != nil {
			m.err = fmt.Errorf("failed to fetch keys: %v", err)
			return m, nil
		}
		if len(keys) == 0 {
			m.err = fmt.Errorf("no public SSH keys found for GitHub user %q", val)
			return m, nil
		}
		m.config.GitHubUser = val
		m.config.SSHKeys = keys
		m.err = nil
		m.state = stateSummary

	case stateSummary:
		m.state = stateConfirm
		m.input.SetValue("")
		m.input.Placeholder = "Type DESTROY to confirm"

	case stateConfirm:
		if m.input.Value() == "DESTROY" {
			m.state = stateInstalling
			m.installStep = 0
			return m, tea.Batch(tick(), runInstallation(m.config))
		}
		m.err = fmt.Errorf("type DESTROY to confirm, or press q to cancel")

	case stateComplete, stateError:
		return m, tea.Quit
	}

	return m, nil
}

func (m model) View() string {
	switch m.state {
	case stateFireTransition:
		return m.viewFireTransition()
	case stateSplash:
		return m.viewSplash()
	case stateGravityOut:
		return m.viewGravityAnimation()
	case stateNetworkCheck:
		return m.viewNetworkCheck()
	case stateInstalling:
		return m.viewInstalling()
	case stateComplete:
		return m.viewComplete()
	case stateError:
		return m.viewError()
	default:
		return m.viewWizard()
	}
}
