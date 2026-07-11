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
        statix
        deadnix

        # Development utilities
        git
        direnv
        pre-commit

        # Shell and terminal tools
        shellcheck
        shfmt
        gum

        # Documentation tools
        (python3.withPackages (ps: with ps; [ mkdocs-material mkdocs-macros ]))
        markdownlint-cli

        # Build tools
        gnumake
      ];

    in flake-utils.lib.eachDefaultSystem (system: {
      # Development shell
      devShells.default = pkgs.mkShell {
        buildInputs = devTools;

        shellHook = ''
          echo "🚀 tuinix development environment"
          echo ""
          echo "Testing:"
          echo "  nix run .#test-install  - Build ISO and launch installer in QEMU VM"
          echo ""
          echo "Building:"
          echo "  nix build .#nixosConfigurations.<hostname>.config.system.build.toplevel"
          echo "  nix build .#nixosConfigurations.<hostname>.config.system.build.isoImage"
          echo "  nixos-rebuild switch --flake .#<hostname>"
          echo ""
          echo "Documentation:"
          echo "  nix run .#docs-serve  - Serve docs locally"
          echo "  nix run .#docs-build  - Build docs to site/"
          echo "  nix run .#docs-deploy - Deploy docs to GitHub Pages"
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

      # Quick test: build installer ISO and launch in QEMU
      apps.test-install = {
        type = "app";
        program = toString (pkgs.writeShellScript "test-install" ''
          set -e
          echo "Building installer ISO..."
          nix build .#nixosConfigurations.installer.config.system.build.isoImage --max-jobs auto --cores 0
          ISO=$(find result/iso -name "*.iso" | head -1)
          if [ -z "$ISO" ]; then
            echo "ERROR: No ISO found in result/iso/"
            exit 1
          fi
          echo "ISO built: $ISO"

          DISK="tuinix-test.qcow2"
          if [ ! -f "$DISK" ]; then
            echo "Creating 50G test disk..."
            ${pkgs.qemu}/bin/qemu-img create -f qcow2 "$DISK" 50G
          fi

          # Find OVMF firmware
          OVMF_CODE="${pkgs.OVMF.fd}/FV/OVMF_CODE.fd"
          OVMF_VARS_SRC="${pkgs.OVMF.fd}/FV/OVMF_VARS.fd"
          OVMF_VARS="$PWD/.tuinix-test-OVMF_VARS.fd"
          cp -f "$OVMF_VARS_SRC" "$OVMF_VARS"
          chmod 600 "$OVMF_VARS"

          echo "Launching QEMU..."
          ${pkgs.qemu}/bin/qemu-system-x86_64 \
            -enable-kvm \
            -m 8G \
            -smp 4 \
            -cpu host \
            -machine q35,accel=kvm \
            -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
            -drive if=pflash,format=raw,file="$OVMF_VARS" \
            -drive file="$DISK",format=qcow2,if=none,id=disk0 \
            -device virtio-blk-pci,drive=disk0,serial=tuinix-root \
            -cdrom "$ISO" \
            -boot order=dc,menu=on \
            -netdev user,id=net0 \
            -device virtio-net-pci,netdev=net0 \
            -display sdl \
            -usb -device qemu-xhci -device usb-tablet \
            -name "tuinix installer test"
        '');
      };

      # Packages
      packages =
        # VM runners for each host (with VM-specific overrides)
        (lib.genAttrs (map (name: "vm-${name}") hostNames) (vmName:
          let hostname = lib.removePrefix "vm-" vmName;
          in (mkNixosConfig hostname [ ./profiles/vm ]).config.system.build.vm))
        //

        # ISO images (only for configurations that have ISO support)
        (lib.mapAttrs' (hostname: config:
          lib.nameValuePair "${hostname}" config.config.system.build.isoImage)
          (lib.filterAttrs (name: _: lib.hasPrefix "iso-" name)
            self.nixosConfigurations));

    }) // {

      # NixOS configurations
      # Only x86_64 configs are evaluated by default (nix flake check).
      # The aarch64 installer is included but built separately.
      nixosConfigurations =
        (lib.genAttrs hostNames (hostname: mkNixosConfig hostname [ ])) //

        # ISO configurations for installation
        {
          # x86_64 installer
          "installer" = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            specialArgs = {
              inherit inputs;
              hostname = "nixos";
              inherit (nixpkgs) lib;
              offlineSystemClosure = null;
            };
            modules = [ (import ./installer.nix { system = "x86_64-linux"; }) ];
          };

          # aarch64 installer - build separately: nix build .#nixosConfigurations.installer-aarch64...
          "installer-aarch64" = nixpkgs.lib.nixosSystem {
            system = "aarch64-linux";
            specialArgs = {
              inherit inputs;
              hostname = "nixos";
              inherit (nixpkgs) lib;
              offlineSystemClosure = null;
            };
            modules =
              [ (import ./installer.nix { system = "aarch64-linux"; }) ];
          };
        };

    };
}
