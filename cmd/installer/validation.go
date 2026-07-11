package main

import (
	"fmt"
	"io"
	"net/http"
	"regexp"
	"strings"
	"time"
)

// reservedUsernames would collide with accounts the shipped configuration
// already defines (or break evaluation entirely).
var reservedUsernames = map[string]bool{
	"root": true, "admin": true, "user": true, "nixos": true,
}

func isValidUsername(s string) bool {
	if s == "" || reservedUsernames[s] {
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

// reservedHostnames resolve to flake outputs that are NOT the generated
// host config (the ISO configs and the shipped example host).
var reservedHostnames = map[string]bool{
	"installer": true, "installer-aarch64": true, "laptop": true,
}

func isValidHostname(s string) bool {
	if s == "" || len(s) > 63 || reservedHostnames[s] {
		return false
	}
	// RFC 952/1123: no leading or trailing hyphen
	matched, _ := regexp.MatchString(`^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$`, s)
	return matched
}

func generateHostID() string {
	return fmt.Sprintf("%08x", uint32(time.Now().UnixNano())&0xFFFFFFFF)
}

// fetchGitHubKeys fetches public SSH keys for a GitHub user
func fetchGitHubKeys(username string) ([]string, error) {
	url := fmt.Sprintf("https://github.com/%s.keys", username)
	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("HTTP request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == 404 {
		return nil, fmt.Errorf("GitHub user %q not found", username)
	}
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("GitHub returned status %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	var keys []string
	for _, line := range strings.Split(strings.TrimSpace(string(body)), "\n") {
		line = strings.TrimSpace(line)
		if line != "" {
			keys = append(keys, line)
		}
	}
	return keys, nil
}
