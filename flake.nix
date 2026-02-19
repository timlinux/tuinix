{
  description = "tuinix - A Pure Terminal Based Linux Experience";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, nixos-hardware, disko, home-manager, flake-utils
    , ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      lib = nixpkgs.lib;

      # Dynamically discover hosts from the hosts directory
      hostsDir = ./hosts;
      hostNames = builtins.attrNames (builtins.readDir hostsDir);

      # Helper function to create NixOS configurations
      mkNixosConfig = hostname: extraModules:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs hostname;
            inherit (nixpkgs) lib;
          };
          modules = [
            disko.nixosModules.disko
            home-manager.nixosModules.home-manager
            ./modules
            (hostsDir + "/${hostname}")
          ] ++ extraModules;
        };

      # Generate configurations for all discovered hosts
      mkHostConfigs = extraModules:
        lib.genAttrs hostNames (hostname: mkNixosConfig hostname extraModules);

      # Development tools for the flake environment
      devTools = with pkgs; [
        # Nix tools
        nixfmt-classic
        nix-tree
        nix-diff
        statix
        deadnix

        # Development utilities
        git
        direnv
        pre-commit

        # System tools
        age
        ssh-to-age

        # Shell and terminal tools
        shellcheck
        shfmt
        gum

        # Documentation tools
        (python3.withPackages (ps: with ps; [ mkdocs-material mkdocs-macros ]))
        markdownlint-cli

        # Security tools
        sops

        # Build tools
        gnumake

        # open source clone of claude code
        opencode
      ];

    in flake-utils.lib.eachDefaultSystem (system: {
      # Development shell
      devShells.default = pkgs.mkShell {
        buildInputs = devTools;

        shellHook = ''
          echo "🚀 tuinix development environment"
          echo ""
          echo "Available commands:"
          echo "  nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel"
          echo "  nix build .#nixosConfigurations.<hostname>.config.system.build.isoImage"
          echo "  nixos-rebuild switch --flake .#<hostname>"
          echo ""
          echo "Documentation:"
          echo "  nix run .#docs-serve  - Serve docs locally at http://127.0.0.1:8000"
          echo "  nix run .#docs-build  - Build docs to site/ directory"
          echo "  nix run .#docs-deploy - Deploy docs to GitHub Pages"
          echo ""
          echo "Development tools available:"
          echo "  • nixfmt-classic - Format Nix code"
          echo "  • statix - Static analysis for Nix"
          echo "  • deadnix - Remove unused Nix code"
          echo "  • shellcheck - Shell script analysis"
          echo "  • pre-commit - Git hooks"
          echo ""

          # Set up direnv if not already done
          if [ ! -f .envrc ]; then
            echo "use flake" > .envrc
            echo "✅ Created .envrc for direnv integration"
            echo "   Run 'direnv allow' to enable automatic environment loading"
          fi
        '';
      };

      # Formatter
      formatter = pkgs.nixfmt-classic;

      # Documentation apps
      apps.docs-serve = let
        mkdocsEnv = pkgs.python3.withPackages
          (ps: with ps; [ mkdocs-material mkdocs-macros ]);
      in {
        type = "app";
        program = toString (pkgs.writeShellScript "docs-serve" ''
          export PATH="${mkdocsEnv}/bin:$PATH"
          mkdocs serve
        '');
      };
      apps.docs-build = let
        mkdocsEnv = pkgs.python3.withPackages
          (ps: with ps; [ mkdocs-material mkdocs-macros ]);
      in {
        type = "app";
        program = toString (pkgs.writeShellScript "docs-build" ''
          export PATH="${mkdocsEnv}/bin:$PATH"
          mkdocs build
        '');
      };
      apps.docs-deploy = {
        type = "app";
        program = toString (pkgs.writeShellScript "docs-deploy" ''
          export PATH="${pkgs.gh}/bin:$PATH"
          echo "Triggering Documentation workflow on GitHub Actions..."
          gh workflow run docs.yml
          echo "Workflow dispatched. Monitor at: https://github.com/timlinux/tuinix/actions/workflows/docs.yml"
        '');
      };

      # Packages
      packages =
        # VM runners for each host (with VM-specific overrides)
        # Only generate VMs for x86_64 hosts (skip r36s which is armv7l)
        (lib.genAttrs
          (map (name: "vm-${name}")
            (builtins.filter (name: name != "r36s") hostNames))
          (vmName:
            let hostname = lib.removePrefix "vm-" vmName;
            in (mkNixosConfig hostname [ ./profiles/vm ]).config.system.build.vm))
        //

        # ISO images (only for configurations that have ISO support)
        (lib.mapAttrs' (hostname: config:
          lib.nameValuePair "${hostname}" config.config.system.build.isoImage)
          (lib.filterAttrs (name: _: lib.hasPrefix "iso-" name)
            self.nixosConfigurations))
        //

        # SD images for R36S (built from r36s nixosConfiguration)
        (let
          r36sConfig = self.nixosConfigurations.r36s or null;
        in if r36sConfig != null && r36sConfig.config ? system.build.sdImage
           then { "sd-r36s" = r36sConfig.config.system.build.sdImage; }
           else { });

    }) // {

      # NixOS configurations (dynamically generated)
      nixosConfigurations = let
        # Build a reference system configuration for offline installation
        # This config represents the "base" system that will be installed
        mkReferenceConfig = system:
          nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = {
              inherit inputs;
              hostname = "offline-reference";
              inherit (nixpkgs) lib;
            };
            modules = [
              disko.nixosModules.disko
              home-manager.nixosModules.home-manager
              ./modules
              # Minimal reference configuration with all features enabled
              ({ config, lib, pkgs, ... }: {
                # Enable all the features we want available offline
                tuinix.networking.networkmanager.enable = true;
                tuinix.networking.iphone-tethering.enable = true;
                tuinix.zfs.enable = lib.mkIf (system == "x86_64-linux") true;

                # Basic system config
                networking.hostName = "offline-reference";
                networking.hostId = "00000000";
                system.stateVersion = "25.11";

                # Include a basic user for the closure
                users.users.user = {
                  isNormalUser = true;
                  extraGroups = [ "wheel" "networkmanager" ];
                };

                # Home-manager config
                home-manager.users.user = { pkgs, ... }: {
                  home.stateVersion = "24.11";
                };

                # Boot configuration - use GRUB for broader compatibility
                boot.loader.grub.enable = true;
                boot.loader.grub.device = "nodev";
                boot.loader.grub.efiSupport = true;
                boot.loader.grub.efiInstallAsRemovable = true;

                # Essential packages
                environment.systemPackages = with pkgs; [
                  vim
                  git
                  curl
                  wget
                  htop
                  tree
                ];

                # Filesystem placeholder (disko requires this)
                fileSystems."/" = {
                  device = "/dev/disk/by-label/nixos";
                  fsType = "ext4";
                };
                fileSystems."/boot" = {
                  device = "/dev/disk/by-label/boot";
                  fsType = "vfat";
                };
              })
            ];
          };

        # Reference configs for each architecture
        referenceX86 = mkReferenceConfig "x86_64-linux";
        referenceAarch64 = mkReferenceConfig "aarch64-linux";

        # Hosts that need different architectures
        # r36s uses armv7l (32-bit ARM) due to Allwinner A33 SoC
        specialArchHosts = {
          "r36s" = "armv7l-linux";
        };

        # Filter out special arch hosts from dynamic discovery
        standardHostNames = builtins.filter
          (name: !(builtins.hasAttr name specialArchHosts))
          hostNames;
      in
        # Regular host configurations (x86_64)
        (lib.genAttrs standardHostNames
          (hostname: mkNixosConfig hostname [ ])) //

        # Special architecture hosts (like r36s with armv7l)
        (lib.mapAttrs (hostname: archSystem:
          nixpkgs.lib.nixosSystem {
            system = archSystem;
            specialArgs = {
              inherit inputs hostname;
              inherit (nixpkgs) lib;
            };
            modules = [
              # Don't include disko or home-manager for minimal embedded systems
              ./modules
              (hostsDir + "/${hostname}")
            ];
          }) specialArchHosts) //

        # ISO configurations for installation
        {
          # x86_64 installer with offline support
          "installer" = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = {
              inherit inputs;
              hostname = "nixos";
              inherit (nixpkgs) lib;
              # Pass the reference system's toplevel for offline installation
              offlineSystemClosure = referenceX86.config.system.build.toplevel;
            };
            modules = [ (import ./installer.nix { system = "x86_64-linux"; }) ];
          };

          # aarch64 installer with offline support
          "installer-aarch64" = nixpkgs.lib.nixosSystem {
            system = "aarch64-linux";
            specialArgs = {
              inherit inputs;
              hostname = "nixos";
              inherit (nixpkgs) lib;
              # Pass the reference system's toplevel for offline installation
              offlineSystemClosure = referenceAarch64.config.system.build.toplevel;
            };
            modules =
              [ (import ./installer.nix { system = "aarch64-linux"; }) ];
          };
        };

    };
}
