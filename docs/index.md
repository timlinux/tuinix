---
hide:
  - navigation
  - toc
---

<div class="tx-hero" markdown>

<figure class="tx-hero__logo" markdown>
![tuinix logo](assets/logo.png){ width="180" }
</figure>

# tuinix

<p class="tx-hero__tagline">A Pure Terminal Based Linux Experience</p>

No desktop environment. No window manager. Just a carefully curated terminal on a
reproducible, declarative NixOS foundation with ZFS encryption.

[Download & Install](installation/bare-metal.md){ .md-button .md-button--primary }
[Try in a VM](installation/vm.md){ .md-button }

</div>

## Install on Your Machine

Most users want to grab the ISO and install tuinix on real hardware.
An internet connection is required during installation.

<div class="tx-features" markdown>

<div class="tx-feature" markdown>

### :material-download: 1. Get the ISO

Download [{{ iso.filename }}]({{ iso.download_url }}) ({{ iso.version }}) or build it yourself from source.

```bash
# Or build from source
git clone https://github.com/timlinux/tuinix.git
cd tuinix && ./scripts/build-iso.sh
```

</div>

<div class="tx-feature" markdown>

### :material-usb-flash-drive: 2. Flash & Boot

Write the ISO to a USB drive and boot from it.
UEFI is required -- disable Secure Boot.

Use [balenaEtcher](https://etcher.balena.io/) or
[Ventoy](https://www.ventoy.net/) to flash the ISO.

??? tip "Advanced: using dd"

    ```bash
    sudo dd if={{ iso.filename }} of=/dev/sdX bs=4M status=progress
    ```

</div>

<div class="tx-feature" markdown>

### :material-wizard-hat: 3. Run the Installer

The interactive installer walks you through disk selection,
ZFS encryption passphrase, locale, and hostname.

```bash
sudo scripts/install.sh
```

</div>

</div>

[Full Bare Metal Guide :material-arrow-right:](installation/bare-metal.md){ .md-button .md-button--primary }
[Test in a Virtual Machine :material-arrow-right:](installation/vm.md){ .md-button }

---

## What You Get

<div class="tx-features" markdown>

<div class="tx-feature" markdown>

### :material-snowflake: NixOS + Flakes

Fully reproducible, declarative system configuration.
Roll back to any previous generation instantly.

</div>

<div class="tx-feature" markdown>

### :material-shield-lock: ZFS Encryption

Native ZFS encryption with compression, checksums,
snapshots, and self-healing data integrity.

</div>

<div class="tx-feature" markdown>

### :material-console: Terminal Only

No X11. No Wayland. Minimal resource usage,
maximum productivity. Every byte serves a purpose.

</div>

<div class="tx-feature" markdown>

### :material-arrow-u-left-top: Instant Rollbacks

Every system change creates a new generation.
Boot into any previous state from GRUB.

</div>

</div>

---

## After Installation

Once installed, your system boots to a pure terminal with ZFS-encrypted storage
and your tuinix flake at `~/tuinix` for customization.

- [Post-Install Guide](usage/post-install.md) -- First boot, networking, updates
- [ZFS Management](usage/zfs.md) -- Snapshots, scrubs, recovery

---

## Contributing

Want to hack on tuinix itself? The development environment runs on any machine
with Nix installed.

- [Development Guide](contributing/development.md) -- Build, test, iterate
- [Contributing Guidelines](contributing/guidelines.md) -- Workflow and standards
- [AI/LLM Tool Policy](contributing/ai-policy.md) -- Rules for AI-assisted contributions
