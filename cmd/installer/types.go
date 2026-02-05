package main

import (
	"time"

	"github.com/charmbracelet/bubbles/textinput"
	"github.com/charmbracelet/bubbles/viewport"
	"github.com/charmbracelet/harmonica"
	"github.com/charmbracelet/lipgloss"
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
	stateNetworkCheck
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
	stateSSH
	stateGitHubUser
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
	stateSSH: {
		title: "SSH Server",
		description: `Choose whether to enable the SSH server
on the installed system.

SSH allows remote access to your machine
over the network. When enabled:
• OpenSSH server runs on port 22
• Root login via password is disabled
• Only key-based root login is allowed
• Password auth is disabled by default

The firewall will also be enabled with
port 22 open for SSH connections.

You will be asked for your GitHub username
so we can fetch your public SSH keys.

Recommended for servers and headless
machines. You can change this later in
your NixOS configuration.`,
		stepNum: 13,
	},
	stateGitHubUser: {
		title: "GitHub Username",
		description: `Enter your GitHub username to fetch your
public SSH keys.

Your public keys will be downloaded from:
  https://github.com/<username>.keys

These keys will be added to your
authorized_keys file, allowing you to
SSH into this machine using your existing
GitHub SSH keys.

Password authentication will be disabled,
so key-based access is the only way to
log in remotely.`,
		stepNum: 14,
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
		stepNum: 15,
	},
	stateConfirm: {
		title: "Final Confirmation",
		description: `DANGER: Point of no return!

You are about to PERMANENTLY DESTROY
all data on the selected disk(s).

This action cannot be undone.

To proceed, type DESTROY exactly.
To cancel, press Ctrl+C or q.`,
		stepNum: 16,
	},
}

const totalSteps = 16

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
	EnableSSH     bool
	GitHubUser    string
	SSHKeys       []string
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
	state        installState
	nextState    installState
	prevState    installState // For detecting state transitions
	config       Config
	width        int
	height       int
	input        textinput.Model
	viewport     viewport.Model
	err          error
	disks        []diskInfo
	selectedIdx  int
	diskSelected []bool // For multi-disk selection (toggle with space)
	locales      []string
	keymaps      []keymapEntry

	// Animation state
	fireParticles []fireParticle
	physicsChars  []physicsChar
	animTick      int
	animDone      bool
	prevContent   string

	// Spring animations for widgets
	leftSpring     harmonica.Spring
	rightSpring    harmonica.Spring
	leftX          float64 // Current X position of left panel
	leftXVel       float64 // Velocity of left panel
	rightX         float64 // Current X position of right panel
	rightXVel      float64 // Velocity of right panel
	springAnimating bool   // Whether spring animation is in progress

	// Network check
	networkOk bool

	// Installation progress
	installLog  []string
	installStep int
	installErr  error
	logTail     []string // Last 3 lines from install log for live display
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
type networkCheckMsg struct {
	ok bool
}
type logTailMsg struct {
	lines       []string
	currentStep int
}
