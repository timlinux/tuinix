package main

import (
	"bytes"
	"fmt"
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

// Brand colors
var (
	colorOrange  = lipgloss.Color("#E95420") // Primary brand
	colorNixBlue = lipgloss.Color("#5277C3") // Info/prompts
	colorGreen   = lipgloss.Color("#28A745") // Success
	colorRed     = lipgloss.Color("#DC3545") // Errors
	colorAmber   = lipgloss.Color("#FFC107") // Warnings
	colorEarth   = lipgloss.Color("#654321") // Details
	colorWhite   = lipgloss.Color("#FFFFFF")
	colorGray    = lipgloss.Color("#666666")
)

// Pre-rendered ASCII mascot logo (compact version for header)
const mascotLogo = `  ▗▆▇▇▆▄
  ▎╷──┊▝╴
  ▘▅▆▅▄▇▊
  ▊▗▎▉┊▝╴
  ▍▝▏▋▁▉┊
▗▆▄▂┒╺▉▄▆▄
 ┈╹╎┊▗▖▂┈▆╴
  ▆▍╾▆▅▆╿▅
   ▝▁▇▂▗▘╹╴
    ╴▁▆▂▄▅
     ▆▄┈▄▇`

// Figlet-style TUINIX title
const tuinixTitle = `████████╗██╗   ██╗██╗███╗   ██╗██╗██╗  ██╗
╚══██╔══╝██║   ██║██║████╗  ██║██║╚██╗██╔╝
   ██║   ██║   ██║██║██╔██╗ ██║██║ ╚███╔╝
   ██║   ██║   ██║██║██║╚██╗██║██║ ██╔██╗
   ██║   ╚██████╔╝██║██║ ╚████║██║██╔╝ ██╗
   ╚═╝    ╚═════╝ ╚═╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝`

// Styles
var (
	titleStyle = lipgloss.NewStyle().
			Foreground(colorOrange).
			Bold(true)

	promptStyle = lipgloss.NewStyle().
			Foreground(colorNixBlue).
			Bold(true)

	successStyle = lipgloss.NewStyle().
			Foreground(colorGreen)

	errorStyle = lipgloss.NewStyle().
			Foreground(colorRed)

	warningStyle = lipgloss.NewStyle().
			Foreground(colorAmber)

	detailStyle = lipgloss.NewStyle().
			Foreground(colorEarth)

	grayStyle = lipgloss.NewStyle().
			Foreground(colorGray)

	borderStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(colorOrange)

	headerLogoStyle = lipgloss.NewStyle().
			Foreground(colorOrange)

	headerTitleStyle = lipgloss.NewStyle().
				Foreground(colorNixBlue).
				Bold(true)

	stepStyle = lipgloss.NewStyle().
			Foreground(colorAmber).
			Bold(true).
			Align(lipgloss.Center)

	footerStyle = lipgloss.NewStyle().
			Foreground(colorGray).
			Align(lipgloss.Center)
)

// Installation state
type installState int

const (
	stateFireTransition installState = iota
	stateSplash
	stateGravityOut
	stateUsername
	stateFullname
	stateEmail
	stateHostname
	stateDisk
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
		stepNum: 4,
	},
	stateDisk: {
		title: "Target Disk",
		description: `Select the disk to install tuinix on.

WARNING: The selected disk will be
COMPLETELY ERASED! All existing data,
partitions, and operating systems will
be destroyed.

The installer will create:
• EFI boot partition (512MB)
• Encrypted ZFS pool (rest of disk)

ZFS datasets created:
• NIXROOT/root - System root
• NIXROOT/nix  - Nix store
• NIXROOT/home - User data`,
		stepNum: 5,
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
		stepNum: 6,
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
		stepNum: 7,
	},
	stateSummary: {
		title: "Review Configuration",
		description: `Please review your installation settings.

After confirmation, the installer will:
1. Format the disk with ZFS encryption
2. Generate NixOS configuration
3. Install the base system
4. Configure your user account
5. Set up git with your identity

This process takes 10-30 minutes
depending on your hardware and
internet connection speed.`,
		stepNum: 8,
	},
	stateConfirm: {
		title: "Final Confirmation",
		description: `DANGER: Point of no return!

You are about to PERMANENTLY DESTROY
all data on the selected disk.

This action cannot be undone.

To proceed, type DESTROY exactly.
To cancel, press Ctrl+C or q.`,
		stepNum: 9,
	},
}

const totalSteps = 9

// Config holds all installation configuration
type Config struct {
	Username    string
	Fullname    string
	Email       string
	Hostname    string
	Disk        string
	HostID      string
	Locale      string
	Keymap      string
	SpaceBoot   string
	SpaceNix    string
	SpaceHome   string
	SpaceAtuin  string
	ZFSPoolName string
	ProjectRoot string
	WorkDir     string
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
	locales     []string
	keymaps     []string

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
		keymaps:  []string{"us", "uk", "pt", "br", "de", "fr", "es"},
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
		case "up", "k":
			if m.state == stateDisk || m.state == stateLocale || m.state == stateKeymap {
				if m.selectedIdx > 0 {
					m.selectedIdx--
				}
			}
		case "down", "j":
			if m.state == stateDisk && m.selectedIdx < len(m.disks)-1 {
				m.selectedIdx++
			} else if m.state == stateLocale && m.selectedIdx < len(m.locales)-1 {
				m.selectedIdx++
			} else if m.state == stateKeymap && m.selectedIdx < len(m.keymaps)-1 {
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
		m.state == stateEmail || m.state == stateHostname || m.state == stateConfirm {
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
		m.state = stateHostname
		m.input.SetValue("")
		m.input.Placeholder = "e.g., laptop, desktop, server"

	case stateHostname:
		val := strings.TrimSpace(m.input.Value())
		if !isValidHostname(val) {
			m.err = fmt.Errorf("invalid hostname: use letters, numbers, and hyphens only")
			return m, nil
		}
		m.config.Hostname = val
		m.err = nil
		m.state = stateDisk
		m.disks = getAvailableDisks()
		m.selectedIdx = 0

	case stateDisk:
		if len(m.disks) > 0 {
			m.config.Disk = m.disks[m.selectedIdx].Path
			m.config.HostID = generateHostID()
			m.state = stateLocale
			m.selectedIdx = 0
		}

	case stateLocale:
		m.config.Locale = m.locales[m.selectedIdx]
		m.state = stateKeymap
		m.selectedIdx = 0

	case stateKeymap:
		m.config.Keymap = m.keymaps[m.selectedIdx]
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
	// Left side: mascot logo
	logoLines := strings.Split(mascotLogo, "\n")
	styledLogo := make([]string, len(logoLines))
	for i, line := range logoLines {
		styledLogo[i] = headerLogoStyle.Render(line)
	}
	logoBlock := strings.Join(styledLogo, "\n")

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
	descText := detailStyle.Width(leftWidth).Render(step.description)
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
	case stateUsername, stateFullname, stateEmail, stateHostname, stateConfirm:
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

	case stateDisk:
		var diskList strings.Builder
		for i, disk := range m.disks {
			cursor := "  "
			style := lipgloss.NewStyle().Foreground(colorWhite)
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

	case stateLocale:
		var optList strings.Builder
		for i, opt := range m.locales {
			cursor := "  "
			style := lipgloss.NewStyle().Foreground(colorWhite)
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
		for i, opt := range m.keymaps {
			cursor := "  "
			style := lipgloss.NewStyle().Foreground(colorWhite)
			if i == m.selectedIdx {
				cursor = "> "
				style = style.Foreground(colorOrange).Bold(true)
			}
			optList.WriteString(style.Render(cursor + opt))
			optList.WriteString("\n")
		}
		hint := grayStyle.Render("\nUp/Down to select | Enter to confirm")
		content = optList.String() + hint

	case stateSummary:
		content = promptStyle.Render("User Account") + "\n" +
			successStyle.Render(fmt.Sprintf("  Username:  %s", m.config.Username)) + "\n" +
			detailStyle.Render(fmt.Sprintf("  Full name: %s", m.config.Fullname)) + "\n" +
			detailStyle.Render(fmt.Sprintf("  Email:     %s", m.config.Email)) + "\n\n" +
			promptStyle.Render("System") + "\n" +
			detailStyle.Render(fmt.Sprintf("  Hostname:  %s", m.config.Hostname)) + "\n" +
			detailStyle.Render(fmt.Sprintf("  Disk:      %s", m.config.Disk)) + "\n" +
			detailStyle.Render(fmt.Sprintf("  Host ID:   %s", m.config.HostID)) + "\n" +
			detailStyle.Render(fmt.Sprintf("  Locale:    %s", m.config.Locale)) + "\n" +
			detailStyle.Render(fmt.Sprintf("  Keyboard:  %s", m.config.Keymap)) + "\n\n" +
			promptStyle.Render("Disk Allocation") + "\n" +
			detailStyle.Render(fmt.Sprintf("  /boot:      %s", m.config.SpaceBoot)) + "\n" +
			detailStyle.Render(fmt.Sprintf("  /nix:       %s", m.config.SpaceNix)) + "\n" +
			detailStyle.Render(fmt.Sprintf("  /home:      %s", m.config.SpaceHome)) + "\n\n" +
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
	// Full header
	header := m.renderHeader()

	line := m.renderHorizontalLine()

	subtitle := lipgloss.NewStyle().
		Foreground(colorNixBlue).
		Align(lipgloss.Center).
		Width(m.width - 4).
		Render("Terminal-focused NixOS with ZFS encryption")

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
		header,
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

	steps := []string{
		"Generating host configuration",
		"Formatting disk with ZFS",
		"Generating hardware configuration",
		"Installing NixOS",
		"Configuring ZFS boot",
		"Copying flake to new system",
		"Setting up user flake",
		"Setting root password",
		"Finalizing ZFS pool",
	}

	var stepList strings.Builder
	for i, step := range steps {
		var icon, text string
		if i < m.installStep {
			icon = successStyle.Render("[done] ")
			text = successStyle.Render(step)
		} else if i == m.installStep {
			spinChars := []string{"|", "/", "-", "\\"}
			spin := spinChars[m.animTick%len(spinChars)]
			icon = warningStyle.Render("[" + spin + "] ")
			text = warningStyle.Render(step + "...")
		} else {
			icon = grayStyle.Render("[ ] ")
			text = grayStyle.Render(step)
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

	info := lipgloss.JoinVertical(lipgloss.Left,
		promptStyle.Render("Your tuinix system is ready!"),
		"",
		detailStyle.Render("Login credentials:"),
		successStyle.Render(fmt.Sprintf("  Username: %s", m.config.Username)),
		warningStyle.Render("  Password: changeme"),
		errorStyle.Render("  ! Change immediately after first login!"),
		"",
		detailStyle.Render("Your flake is at:"),
		successStyle.Render(fmt.Sprintf("  /home/%s/tuinix", m.config.Username)),
		"",
		detailStyle.Render("Rebuild command:"),
		grayStyle.Render(fmt.Sprintf("  sudo nixos-rebuild switch --flake .#%s", m.config.Hostname)),
		"",
		successStyle.Render("[done] Git is pre-configured with your identity"),
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

	info := lipgloss.JoinVertical(lipgloss.Left,
		errorStyle.Render("An error occurred during installation:"),
		"",
		detailStyle.Render(errMsg),
		"",
		warningStyle.Render("Please check the error message above."),
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
	cmd := exec.Command("lsblk", "-d", "-n", "-b", "-o", "SIZE", c.Disk)
	output, err := cmd.Output()
	if err != nil {
		c.SpaceNix = "50G"
		c.SpaceHome = "100G"
		c.SpaceAtuin = "1G"
		return
	}

	var sizeBytes int64
	fmt.Sscanf(strings.TrimSpace(string(output)), "%d", &sizeBytes)
	sizeGB := sizeBytes / 1024 / 1024 / 1024

	if sizeGB == 0 {
		sizeGB = 100
	}

	bootGB := int64(5)
	nixGB := sizeGB * 5 / 100
	if nixGB < 20 {
		nixGB = 20
	}
	atuinGB := sizeGB * 5 / 10000
	if atuinGB < 1 {
		atuinGB = 1
	}
	homeGB := sizeGB - bootGB - nixGB - atuinGB

	c.SpaceBoot = fmt.Sprintf("%dG", bootGB)
	c.SpaceNix = fmt.Sprintf("%dG", nixGB)
	c.SpaceAtuin = fmt.Sprintf("%dG", atuinGB)
	c.SpaceHome = fmt.Sprintf("%dG", homeGB)
}

func tick() tea.Cmd {
	return tea.Tick(time.Millisecond*33, func(t time.Time) tea.Msg {
		return tickMsg(t)
	})
}

func runCommand(name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	err := cmd.Run()
	output := stdout.String() + stderr.String()
	return output, err
}

// Installation functions - ported from install.sh

func runInstallation(c Config) tea.Cmd {
	return func() tea.Msg {
		if err := generateHostConfig(c); err != nil {
			return installErrMsg{err: fmt.Errorf("generate host config: %w", err)}
		}

		if err := formatDisk(c); err != nil {
			return installErrMsg{err: fmt.Errorf("format disk: %w", err)}
		}

		if err := generateHardwareConfig(c); err != nil {
			return installErrMsg{err: fmt.Errorf("generate hardware config: %w", err)}
		}

		if err := installNixOS(c); err != nil {
			return installErrMsg{err: fmt.Errorf("install nixos: %w", err)}
		}

		if err := configureZFSBoot(c); err != nil {
			return installErrMsg{err: fmt.Errorf("configure zfs boot: %w", err)}
		}

		if err := copyFlake(c); err != nil {
			return installErrMsg{err: fmt.Errorf("copy flake: %w", err)}
		}

		if err := setupUserFlake(c); err != nil {
			return installErrMsg{err: fmt.Errorf("setup user flake: %w", err)}
		}

		if err := finalizeZFSPool(c); err != nil {
			return installErrMsg{err: fmt.Errorf("finalize zfs pool: %w", err)}
		}

		return installDoneMsg{}
	}
}

func generateHostConfig(c Config) error {
	workDir := c.WorkDir
	os.RemoveAll(workDir)

	if _, err := runCommand("cp", "-r", c.ProjectRoot, workDir); err != nil {
		return fmt.Errorf("copy project: %w", err)
	}

	hostDir := filepath.Join(workDir, "hosts", c.Hostname)
	if err := os.MkdirAll(hostDir, 0755); err != nil {
		return fmt.Errorf("create host dir: %w", err)
	}

	usersDir := filepath.Join(workDir, "users")

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
    initialPassword = "changeme";
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
		c.Username, c.Fullname, c.Username,
		c.Username,
		c.Fullname, c.Email)

	if err := os.WriteFile(filepath.Join(usersDir, c.Username+".nix"), []byte(userNix), 0644); err != nil {
		return fmt.Errorf("write user nix: %w", err)
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

  tuinix.zfs.enable = true;
  tuinix.zfs.encryption = true;

  i18n.defaultLocale = "%s";
  services.xserver.xkb.layout = "%s";
  console.keyMap = "%s";
}
`, c.Username, c.Locale, c.Keymap, c.Keymap)

	if err := os.WriteFile(filepath.Join(hostDir, "default.nix"), []byte(defaultNix), 0644); err != nil {
		return fmt.Errorf("write default.nix: %w", err)
	}

	templateFile := filepath.Join(workDir, "templates", "disko-template.nix")
	templateContent, err := os.ReadFile(templateFile)
	if err != nil {
		return fmt.Errorf("read disko template: %w", err)
	}

	disksContent := string(templateContent)
	disksContent = strings.ReplaceAll(disksContent, "{{DISK_DEVICE}}", c.Disk)
	disksContent = strings.ReplaceAll(disksContent, "{{HOSTNAME}}", c.Hostname)
	disksContent = strings.ReplaceAll(disksContent, "{{SPACE_BOOT}}", c.SpaceBoot)
	disksContent = strings.ReplaceAll(disksContent, "{{SPACE_NIX}}", c.SpaceNix)
	disksContent = strings.ReplaceAll(disksContent, "{{SPACE_ATUIN}}", c.SpaceAtuin)
	disksContent = strings.ReplaceAll(disksContent, "{{ZFS_POOL_NAME}}", c.ZFSPoolName)

	if err := os.WriteFile(filepath.Join(hostDir, "disks.nix"), []byte(disksContent), 0644); err != nil {
		return fmt.Errorf("write disks.nix: %w", err)
	}

	hardwareNix := fmt.Sprintf(`{ config, lib, pkgs, modulesPath, ... }:

{
  networking.hostId = "%s";
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot = {
    initrd = {
      availableKernelModules = [
        "ahci" "xhci_pci" "virtio_pci" "virtio_scsi"
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

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
}
`, c.HostID)

	if err := os.WriteFile(filepath.Join(hostDir, "hardware.nix"), []byte(hardwareNix), 0644); err != nil {
		return fmt.Errorf("write hardware.nix: %w", err)
	}

	return nil
}

func formatDisk(c Config) error {
	hostDir := filepath.Join(c.WorkDir, "hosts", c.Hostname)
	diskoConfig := filepath.Join(hostDir, "disks.nix")

	os.Remove("/etc/hostid")

	if _, err := runCommand("zgenhostid", c.HostID); err != nil {
		return fmt.Errorf("zgenhostid: %w", err)
	}

	lsblkOutput, _ := runCommand("lsblk", "-nr", "-o", "NAME", c.Disk)
	partitions := strings.Split(lsblkOutput, "\n")
	for i, part := range partitions {
		if i == 0 || part == "" {
			continue
		}
		partPath := "/dev/" + strings.TrimSpace(part)
		runCommand("umount", partPath)
	}

	runCommand("zpool", "export", "-a")

	if _, err := runCommand("disko", "--mode", "disko", diskoConfig); err != nil {
		return fmt.Errorf("disko failed: %w", err)
	}

	return nil
}

func generateHardwareConfig(c Config) error {
	hostDir := filepath.Join(c.WorkDir, "hosts", c.Hostname)

	os.MkdirAll("/tmp/nixos-config", 0755)
	if _, err := runCommand("nixos-generate-config", "--root", "/mnt", "--dir", "/tmp/nixos-config"); err != nil {
		return fmt.Errorf("nixos-generate-config: %w", err)
	}

	hardwareNix := fmt.Sprintf(`{ config, lib, pkgs, modulesPath, ... }:

{
  networking.hostId = "%s";
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot = {
    supportedFilesystems = [ "zfs" ];
    zfs = {
      requestEncryptionCredentials = true;
      forceImportRoot = true;
    };
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

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
  services.zfs.autoScrub.enable = true;
}
`, c.HostID)

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
	if os.Geteuid() != 0 {
		fmt.Println(errorStyle.Render("! This installer must be run as root"))
		fmt.Println(grayStyle.Render("  Use: sudo tuinix-installer"))
		os.Exit(1)
	}

	rand.Seed(time.Now().UnixNano())

	p := tea.NewProgram(initialModel(), tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Printf("Error: %v\n", err)
		os.Exit(1)
	}
}
