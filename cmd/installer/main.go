package main

import (
	"bytes"
	_ "embed"
	"fmt"
	"log"
	"math"
	"math/rand"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/charmbracelet/bubbles/textinput"
	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"golang.org/x/term"
)

// Log file for installation diagnostics
const logFile = "/tmp/tuinix-install.log"

var logger *log.Logger

func initLogger() {
	f, err := os.OpenFile(logFile, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0644)
	if err != nil {
		// Fall back to stderr if we can't create log file
		logger = log.New(os.Stderr, "[tuinix] ", log.LstdFlags)
		return
	}
	logger = log.New(f, "", log.LstdFlags)
}

func logInfo(format string, args ...interface{}) {
	if logger != nil {
		logger.Printf("[INFO] "+format, args...)
	}
}

func logError(format string, args ...interface{}) {
	if logger != nil {
		logger.Printf("[ERROR] "+format, args...)
	}
}

// Brand colors - used sparingly for emphasis
var (
	colorOrange  = lipgloss.Color("#E95420") // Primary brand accent
	colorNixBlue = lipgloss.Color("#5277C3") // Info accent
	colorGreen   = lipgloss.Color("#28A745") // Success
	colorRed     = lipgloss.Color("#DC3545") // Errors
	colorAmber   = lipgloss.Color("#FFC107") // Warnings
	colorEarth   = lipgloss.Color("#654321") // Details
	colorOffWhite = lipgloss.Color("#D4D4D4") // Default text
	colorDimGray  = lipgloss.Color("#808080") // Secondary text
	colorDarkGray = lipgloss.Color("#555555") // Borders, subtle elements
)

// Embedded catimg-rendered mascot logos (24-bit ANSI color)
//
//go:embed logo-header.txt
var mascotLogo string

//go:embed logo-large.txt
var mascotLogoLarge string

// Figlet-style TUINIX title
const tuinixTitle = `████████╗██╗   ██╗██╗███╗   ██╗██╗██╗  ██╗
╚══██╔══╝██║   ██║██║████╗  ██║██║╚██╗██╔╝
   ██║   ██║   ██║██║██╔██╗ ██║██║ ╚███╔╝
   ██║   ██║   ██║██║██║╚██╗██║██║ ██╔██╗
   ██║   ╚██████╔╝██║██║ ╚████║██║██╔╝ ██╗
   ╚═╝    ╚═════╝ ╚═╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝`

// Styles - off-white text by default, color only for emphasis
var (
	titleStyle = lipgloss.NewStyle().
			Foreground(colorOrange).
			Bold(true)

	promptStyle = lipgloss.NewStyle().
			Foreground(colorOffWhite).
			Bold(true)

	successStyle = lipgloss.NewStyle().
			Foreground(colorGreen)

	errorStyle = lipgloss.NewStyle().
			Foreground(colorRed)

	warningStyle = lipgloss.NewStyle().
			Foreground(colorAmber)

	detailStyle = lipgloss.NewStyle().
			Foreground(colorDimGray)

	grayStyle = lipgloss.NewStyle().
			Foreground(colorDimGray)

	borderStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(colorDarkGray)

	headerTitleStyle = lipgloss.NewStyle().
				Foreground(colorNixBlue).
				Bold(true)

	stepStyle = lipgloss.NewStyle().
			Foreground(colorOffWhite).
			Bold(true).
			Align(lipgloss.Center)

	footerStyle = lipgloss.NewStyle().
			Foreground(colorDimGray).
			Align(lipgloss.Center)
)

// Storage mode determines disk layout strategy
type storageMode int

const (
	storageZFSEncryptedSingle storageMode = iota // Encrypted ZFS, single disk (original)
	storageXFS                                   // XFS unencrypted, single disk (max performance)
	storageZFSStripe                             // Encrypted ZFS stripe, multi-disk (combined space)
	storageZFSRaidz                              // Encrypted ZFS raidz, multi-disk (1 disk fault tolerance)
	storageZFSRaidz2                             // Encrypted ZFS raidz2, multi-disk (2 disk fault tolerance)
)

func (s storageMode) String() string {
	switch s {
	case storageZFSEncryptedSingle:
		return "Encrypted ZFS (single disk)"
	case storageXFS:
		return "XFS unencrypted (max performance)"
	case storageZFSStripe:
		return "Encrypted ZFS stripe (combined space)"
	case storageZFSRaidz:
		return "Encrypted ZFS raidz (1-disk fault tolerance)"
	case storageZFSRaidz2:
		return "Encrypted ZFS raidz2 (2-disk fault tolerance)"
	default:
		return "Unknown"
	}
}

func (s storageMode) isZFS() bool {
	return s != storageXFS
}

func (s storageMode) isEncrypted() bool {
	return s != storageXFS
}

func (s storageMode) isMultiDisk() bool {
	return s == storageZFSStripe || s == storageZFSRaidz || s == storageZFSRaidz2
}

func (s storageMode) minDisks() int {
	switch s {
	case storageZFSRaidz:
		return 3
	case storageZFSRaidz2:
		return 4
	case storageZFSStripe:
		return 2
	default:
		return 1
	}
}

// Installation state
type installState int

const (
	stateFireTransition installState = iota
	stateSplash
	stateGravityOut
	stateUsername
	stateFullname
	stateEmail
	statePassword
	statePasswordConfirm
	stateHostname
	stateStorageMode
	stateDisk
	stateDiskMulti
	statePassphrase
	statePassphraseConfirm
	stateLocale
	stateKeymap
	stateSummary
	stateConfirm
	stateInstalling
	stateComplete
	stateError
)

// Step information for wizard
type stepInfo struct {
	title       string
	description string
	stepNum     int
}

var storageModes = []storageMode{
	storageZFSEncryptedSingle,
	storageXFS,
	storageZFSStripe,
	storageZFSRaidz,
	storageZFSRaidz2,
}

var storageModeDescriptions = map[storageMode]string{
	storageZFSEncryptedSingle: "Single disk with AES-256-GCM encryption, compression, and snapshots",
	storageXFS:                "Single disk, no encryption. Maximum raw I/O performance",
	storageZFSStripe:          "Multiple disks combined for maximum space (no redundancy)",
	storageZFSRaidz:           "Multiple disks with single parity. Tolerates 1 disk failure (min 3 disks)",
	storageZFSRaidz2:          "Multiple disks with double parity. Tolerates 2 disk failures (min 4 disks)",
}

var wizardSteps = map[installState]stepInfo{
	stateUsername: {
		title: "User Account",
		description: `Create your user account for the new system.

Your username will be used for:
• Logging into the system
• Your home directory (/home/username)
• Git commit authorship
• File ownership

Username requirements:
• Start with a lowercase letter or underscore
• Can contain lowercase letters, numbers, underscores, hyphens
• No spaces or special characters`,
		stepNum: 1,
	},
	stateFullname: {
		title: "Your Identity",
		description: `Enter your full name as you'd like it to appear.

This will be used for:
• Git commit author name
• System account description
• Any documents or signatures

Example: John Smith, Maria Garcia`,
		stepNum: 2,
	},
	stateEmail: {
		title: "Email Address",
		description: `Enter your email address.

This will be configured in:
• Git global configuration
• System identification

This email will be used for git commits
so make sure it matches your GitHub/GitLab
account if you plan to push code.`,
		stepNum: 3,
	},
	statePassword: {
		title: "Account Password",
		description: `Set the login password for your user
account.

This password will be used for:
• Logging into the system
• sudo commands (admin access)
• Screen unlock

Requirements:
• At least 8 characters
• Use a strong, memorable password
• You will be prompted to confirm it`,
		stepNum: 4,
	},
	statePasswordConfirm: {
		title: "Confirm Password",
		description: `Please re-enter your account password
to confirm.

Make sure you remember this password.
You will need it to log in after
installation.`,
		stepNum: 5,
	},
	stateHostname: {
		title: "Machine Name",
		description: `Choose a hostname for this computer.

The hostname identifies your machine on
the network and in your terminal prompt.

Good examples:
• laptop, desktop, workstation
• dev-machine, home-server
• Your computer's name

Keep it short, memorable, and lowercase.
Use only letters, numbers, and hyphens.`,
		stepNum: 6,
	},
	stateStorageMode: {
		title: "Storage Mode",
		description: `Select how your disk(s) will be configured.

Single disk options:
• Encrypted ZFS - Secure, with snapshots
  and compression (recommended)
• XFS - Maximum performance, no encryption

Multi-disk options (requires 2+ disks):
• ZFS Stripe - Combines all disks into one
  pool for maximum space (no redundancy)
• ZFS Raidz - Single parity, tolerates 1
  disk failure (needs 3+ disks)
• ZFS Raidz2 - Double parity, tolerates 2
  disk failures (needs 4+ disks)`,
		stepNum: 7,
	},
	stateDisk: {
		title: "Target Disk",
		description: `Select the disk to install tuinix on.

WARNING: The selected disk will be
COMPLETELY ERASED! All existing data,
partitions, and operating systems will
be destroyed.`,
		stepNum: 8,
	},
	stateDiskMulti: {
		title: "Select Disks",
		description: `Select the disks to include in your
ZFS pool.

WARNING: ALL selected disks will be
COMPLETELY ERASED! All existing data,
partitions, and operating systems on
every selected disk will be destroyed.

Use Space to toggle disk selection.
The first selected disk will also host
the EFI boot partition.

Press Enter when done selecting.`,
		stepNum: 8,
	},
	statePassphrase: {
		title: "ZFS Encryption Passphrase",
		description: `Set the encryption passphrase for your
ZFS pool.

This passphrase will be required every
time you boot the system. It protects
all data on disk with AES-256-GCM
encryption.

Requirements:
• At least 8 characters
• Use a strong, memorable passphrase
• You will be prompted to confirm it

If you forget this passphrase, your
data cannot be recovered.`,
		stepNum: 9,
	},
	statePassphraseConfirm: {
		title: "Confirm Passphrase",
		description: `Please re-enter your ZFS encryption
passphrase to confirm.

Make sure you remember this passphrase.
You will need it every time you boot.`,
		stepNum: 10,
	},
	stateLocale: {
		title: "System Locale",
		description: `Select your system locale.

This configures:
• Language for system messages
• Number and date formats
• Currency formatting
• Character encoding (UTF-8)

The locale affects terminal output,
file sorting, and application behavior.`,
		stepNum: 11,
	},
	stateKeymap: {
		title: "Keyboard Layout",
		description: `Select your keyboard layout.

This configures the keyboard mapping
for both the console (TTY) and any
graphical applications.

Common layouts:
• us - US English (QWERTY)
• uk - UK English
• de - German (QWERTZ)
• fr - French (AZERTY)`,
		stepNum: 12,
	},
	stateSummary: {
		title: "Review Configuration",
		description: `Please review your installation settings.

After confirmation, the installer will:
1. Format the disk(s)
2. Generate NixOS configuration
3. Install the base system
4. Configure your user account
5. Set up git with your identity

This process takes 10-30 minutes
depending on your hardware and
internet connection speed.`,
		stepNum: 13,
	},
	stateConfirm: {
		title: "Final Confirmation",
		description: `DANGER: Point of no return!

You are about to PERMANENTLY DESTROY
all data on the selected disk(s).

This action cannot be undone.

To proceed, type DESTROY exactly.
To cancel, press Ctrl+C or q.`,
		stepNum: 14,
	},
}

const totalSteps = 14

// Config holds all installation configuration
type Config struct {
	Username      string
	Fullname      string
	Email         string
	Password      string
	Hostname      string
	Disk          string   // Primary disk (single-disk modes, or boot disk for multi-disk)
	Disks         []string // All selected disks (multi-disk modes)
	HostID        string
	Passphrase    string
	StorageMode   storageMode
	Locale        string
	Keymap        string
	ConsoleKeyMap string
	SpaceBoot     string
	SpaceNix      string
	SpaceHome     string
	SpaceAtuin    string
	ZFSPoolName   string
	ProjectRoot   string
	WorkDir       string
}

// Particle for fire effect
type fireParticle struct {
	x, y    float64
	vx, vy  float64
	life    float64
	maxLife float64
	char    rune
}

// Character with physics for gravity animation
type physicsChar struct {
	char        rune
	x, y        float64
	startX      float64
	startY      float64
	vx, vy      float64
	targetY     float64
	bounceCount int
	settled     bool
	color       lipgloss.Color
}

type diskInfo struct {
	Path  string
	Size  string
	Model string
}

type keymapEntry struct {
	Label      string // Display label (e.g. "us", "pt")
	XKBLayout  string // X11/Wayland layout (e.g. "us", "pt")
	ConsoleMap string // Linux console keymap (e.g. "us", "pt-latin1")
}

// Model is the main application model
type model struct {
	state       installState
	nextState   installState
	config      Config
	width       int
	height      int
	input       textinput.Model
	viewport    viewport.Model
	err         error
	disks       []diskInfo
	selectedIdx int
	diskSelected []bool // For multi-disk selection (toggle with space)
	locales     []string
	keymaps     []keymapEntry

	// Animation state
	fireParticles []fireParticle
	physicsChars  []physicsChar
	animTick      int
	animDone      bool
	prevContent   string

	// Installation progress
	installLog  []string
	installStep int
	installErr  error
}

// Messages
type tickMsg time.Time
type installStepMsg struct {
	step int
	msg  string
}
type installDoneMsg struct{}
type installErrMsg struct {
	err error
}

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
		config: Config{
			ZFSPoolName: "NIXROOT",
			SpaceBoot:   "5G",
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

func (m *model) initFireParticles() {
	m.fireParticles = make([]fireParticle, 200)
	for i := range m.fireParticles {
		m.fireParticles[i] = m.newFireParticle()
	}
}

func (m *model) newFireParticle() fireParticle {
	chars := []rune{'░', '▒', '▓', '█', '▄', '▀', '*', '.'}
	return fireParticle{
		x:       float64(m.width/2) + (rand.Float64()-0.5)*float64(m.width/3),
		y:       float64(m.height),
		vx:      (rand.Float64() - 0.5) * 2,
		vy:      -rand.Float64()*3 - 1,
		life:    rand.Float64() * 30,
		maxLife: 30,
		char:    chars[rand.Intn(len(chars))],
	}
}

// stripANSI removes ANSI escape sequences from a string
func stripANSI(s string) string {
	ansiRegex := regexp.MustCompile(`\x1b\[[0-9;]*[a-zA-Z]`)
	return ansiRegex.ReplaceAllString(s, "")
}

func (m *model) initGravityChars(content string) {
	// Strip ANSI codes before processing characters
	cleanContent := stripANSI(content)
	lines := strings.Split(cleanContent, "\n")
	m.physicsChars = nil

	for y, line := range lines {
		for x, ch := range line {
			if ch != ' ' && ch != '\n' {
				m.physicsChars = append(m.physicsChars, physicsChar{
					char:    ch,
					x:       float64(x),
					y:       float64(y),
					startX:  float64(x),
					startY:  float64(y),
					vx:      0,
					vy:      0,
					targetY: float64(m.height - 3),
					color:   colorOrange,
				})
			}
		}
	}
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
			if m.state != stateInstalling && m.state != stateFireTransition && m.state != stateGravityOut && m.state != stateSplash {
				return m, tea.Quit
			}
		case "enter":
			if m.state != stateFireTransition && m.state != stateGravityOut && m.state != stateSplash {
				return m.handleEnter()
			}
		case " ":
			// Space toggles disk selection in multi-disk mode
			if m.state == stateDiskMulti && m.selectedIdx < len(m.disks) {
				m.diskSelected[m.selectedIdx] = !m.diskSelected[m.selectedIdx]
			}
		case "up", "k":
			if m.state == stateDisk || m.state == stateDiskMulti || m.state == stateLocale || m.state == stateKeymap || m.state == stateStorageMode {
				if m.selectedIdx > 0 {
					m.selectedIdx--
				}
			}
		case "down", "j":
			if m.state == stateDisk && m.selectedIdx < len(m.disks)-1 {
				m.selectedIdx++
			} else if m.state == stateDiskMulti && m.selectedIdx < len(m.disks)-1 {
				m.selectedIdx++
			} else if m.state == stateLocale && m.selectedIdx < len(m.locales)-1 {
				m.selectedIdx++
			} else if m.state == stateKeymap && m.selectedIdx < len(m.keymaps)-1 {
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
	}

	// Update text input for input states
	if m.state == stateUsername || m.state == stateFullname ||
		m.state == stateEmail || m.state == statePassword || m.state == statePasswordConfirm ||
		m.state == stateHostname ||
		m.state == statePassphrase || m.state == statePassphraseConfirm ||
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
			m.nextState = stateUsername
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

	case stateInstalling:
		return m, tick()
	}

	return m, nil
}

func (m model) handleEnter() (tea.Model, tea.Cmd) {
	switch m.state {
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
		m.config.Password = val
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
			if m.config.StorageMode.isEncrypted() {
				m.state = statePassphrase
				m.input.SetValue("")
				m.input.Placeholder = "Enter ZFS encryption passphrase"
				m.input.EchoMode = textinput.EchoPassword
				m.input.EchoCharacter = '*'
			} else {
				// XFS mode: skip passphrase, go to locale
				m.state = stateLocale
				m.input.SetValue("")
				m.input.EchoMode = textinput.EchoNormal
				m.input.EchoCharacter = 0
				m.selectedIdx = 0
			}
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

// renderFooter creates the footer with horizontal line and URL
func (m model) renderFooter() string {
	line := strings.Repeat("─", m.width-4)
	url := "https://github.com/timlinux/tuinix"
	return lipgloss.JoinVertical(lipgloss.Center,
		grayStyle.Render(line),
		footerStyle.Width(m.width-4).Render(url),
	)
}

// renderHorizontalLine creates a horizontal separator
func (m model) renderHorizontalLine() string {
	return grayStyle.Render(strings.Repeat("─", m.width-4))
}

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
	leftBox := borderStyle.
		Width(leftWidth).
		Height(contentHeight).
		Render(leftContent)

	// Right column: user inputs
	rightContent := m.renderRightPanel(step.stepNum)
	rightBox := borderStyle.
		Width(rightWidth).
		Height(contentHeight).
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

func (m model) renderRightPanel(stepNum int) string {
	var content string

	switch m.state {
	case stateUsername, stateFullname, stateEmail, statePassword, statePasswordConfirm, stateHostname, statePassphrase, statePassphraseConfirm, stateConfirm:
		inputBox := lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(colorNixBlue).
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
		if m.config.StorageMode.isMultiDisk() {
			diskInfo = infoStyle.Render(fmt.Sprintf("  Disks:     %s", strings.Join(m.config.Disks, ", ")))
		} else {
			diskInfo = infoStyle.Render(fmt.Sprintf("  Disk:      %s", m.config.Disk))
		}

		// Build storage allocation section
		var allocSection string
		if m.config.StorageMode.isZFS() {
			allocSection = promptStyle.Render("Disk Allocation") + "\n" +
				infoStyle.Render(fmt.Sprintf("  /boot:      %s", m.config.SpaceBoot)) + "\n" +
				infoStyle.Render(fmt.Sprintf("  /nix:       %s", m.config.SpaceNix)) + "\n" +
				infoStyle.Render(fmt.Sprintf("  /home:      remainder"))
		} else {
			allocSection = promptStyle.Render("Disk Allocation") + "\n" +
				infoStyle.Render(fmt.Sprintf("  /boot:      %s", m.config.SpaceBoot)) + "\n" +
				infoStyle.Render("  /:          remainder (XFS)")
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
			infoStyle.Render(fmt.Sprintf("  Keyboard:  %s", m.config.Keymap)) + "\n\n" +
			allocSection + "\n\n" +
			grayStyle.Render("Enter to proceed | Ctrl+C to cancel")
	}

	return content
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

// Helper functions

func isValidUsername(s string) bool {
	if s == "" {
		return false
	}
	matched, _ := regexp.MatchString(`^[a-z_][a-z0-9_-]*$`, s)
	return matched
}

func isValidEmail(s string) bool {
	if s == "" {
		return false
	}
	matched, _ := regexp.MatchString(`^[^@]+@[^@]+\.[^@]+$`, s)
	return matched
}

func isValidHostname(s string) bool {
	if s == "" {
		return false
	}
	matched, _ := regexp.MatchString(`^[a-zA-Z0-9-]+$`, s)
	return matched
}

func generateHostID() string {
	return fmt.Sprintf("%08x", uint32(time.Now().UnixNano())&0xFFFFFFFF)
}

// hashPassword generates a SHA-512 crypt hash using mkpasswd
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

func (m model) getInstallStepNames() []string {
	if m.config.StorageMode.isZFS() {
		return []string{
			"Generating host configuration",
			"Formatting disk(s) with ZFS",
			"Generating hardware configuration",
			"Installing NixOS",
			"Configuring ZFS boot",
			"Copying flake to new system",
			"Setting up user flake",
			"Copying install log",
			"Finalizing ZFS pool",
		}
	}
	return []string{
		"Generating host configuration",
		"Formatting disk with XFS",
		"Generating hardware configuration",
		"Installing NixOS",
		"Copying flake to new system",
		"Setting up user flake",
		"Copying install log",
	}
}

func tick() tea.Cmd {
	return tea.Tick(time.Millisecond*33, func(t time.Time) tea.Msg {
		return tickMsg(t)
	})
}

func runCommand(name string, args ...string) (string, error) {
	cmdStr := name + " " + strings.Join(args, " ")
	logInfo("Running command: %s", cmdStr)

	cmd := exec.Command(name, args...)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	err := cmd.Run()
	output := stdout.String() + stderr.String()

	if err != nil {
		logError("Command failed: %s\nError: %v\nOutput: %s", cmdStr, err, output)
	} else {
		logInfo("Command succeeded: %s", cmdStr)
		if output != "" {
			logInfo("Output: %s", output)
		}
	}
	return output, err
}

// Installation functions - ported from install.sh

func runInstallation(c Config) tea.Cmd {
	return func() tea.Msg {
		logInfo("=== Starting installation ===")
		logInfo("Config: Username=%s, Hostname=%s, Disk=%s, StorageMode=%s", c.Username, c.Hostname, c.Disk, c.StorageMode)
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
		c.Username, c.Fullname, c.Username, hashedPassword,
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

  boot.consoleLogLevel = 3;

  i18n.defaultLocale = "%s";
  services.xserver.xkb.layout = "%s";
  console.keyMap = "%s";
}
`, c.Username, zfsConfig, c.Locale, c.Keymap, c.ConsoleKeyMap)

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

func formatDisk(c Config) error {
	logInfo("formatDisk: starting")
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

func main() {
	initLogger()
	logInfo("tuinix installer started")

	if os.Geteuid() != 0 {
		fmt.Println(errorStyle.Render("! This installer must be run as root"))
		fmt.Println(grayStyle.Render("  Use: sudo installer"))
		os.Exit(1)
	}

	rand.Seed(time.Now().UnixNano())

	p := tea.NewProgram(initialModel(), tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		logError("Program error: %v", err)
		fmt.Printf("Error: %v\n", err)
		os.Exit(1)
	}
	logInfo("Installer finished")
}
