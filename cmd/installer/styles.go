package main

import (
	_ "embed"

	"github.com/charmbracelet/lipgloss"
	"github.com/timlinux/blockfont"
)

// Kartoza brand colors
var (
	colorOrange   = lipgloss.Color("#F4811F") // Kartoza orange - primary accent
	colorBlue     = lipgloss.Color("#2C3E50") // Kartoza blue - headers, structure
	colorGray     = lipgloss.Color("#7F8C8D") // Kartoza gray - secondary text
	colorWhite    = lipgloss.Color("#FFFFFF") // White - emphasis text
	colorGreen    = lipgloss.Color("#28A745") // Success
	colorRed      = lipgloss.Color("#DC3545") // Errors
	colorAmber    = lipgloss.Color("#FFC107") // Warnings
	colorOffWhite = lipgloss.Color("#D4D4D4") // Default text
	colorDimGray  = lipgloss.Color("#808080") // Borders, subtle elements
)

// Embedded catimg-rendered mascot logos (24-bit ANSI color)
//
//go:embed logo-header.txt
var mascotLogo string

//go:embed logo-large.txt
var mascotLogoLarge string

//go:embed version.txt
var versionInfo string

// tuinixTitle renders "TUINIX" using the blockfont library
var tuinixTitle = blockfont.RenderText("TUINIX")

// Styles - Kartoza brand palette
var (
	titleStyle = lipgloss.NewStyle().
			Foreground(colorOrange).
			Bold(true)

	promptStyle = lipgloss.NewStyle().
			Foreground(colorWhite).
			Bold(true)

	successStyle = lipgloss.NewStyle().
			Foreground(colorGreen)

	errorStyle = lipgloss.NewStyle().
			Foreground(colorRed)

	warningStyle = lipgloss.NewStyle().
			Foreground(colorAmber)

	detailStyle = lipgloss.NewStyle().
			Foreground(colorGray)

	grayStyle = lipgloss.NewStyle().
			Foreground(colorGray)

	borderStyle = lipgloss.NewStyle().
			Border(lipgloss.NormalBorder()).
			BorderForeground(colorBlue)

	headerTitleStyle = lipgloss.NewStyle().
				Foreground(colorOrange).
				Bold(true)

	stepStyle = lipgloss.NewStyle().
			Foreground(colorWhite).
			Bold(true).
			Align(lipgloss.Center)

	footerStyle = lipgloss.NewStyle().
			Foreground(colorGray).
			Align(lipgloss.Center)

	// Wizard navigation buttons (bottom-left / bottom-right, Tab to focus)
	buttonStyle = lipgloss.NewStyle().
			Foreground(colorOffWhite).
			Background(colorBlue).
			Padding(0, 2)

	buttonFocusedStyle = lipgloss.NewStyle().
				Foreground(colorWhite).
				Background(colorOrange).
				Bold(true).
				Padding(0, 2)
)
