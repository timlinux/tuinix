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

      # NixOS configurations (dynamically generated)
      nixosConfigurations =
        # Regular host configurations
        (mkHostConfigs [ ]) //

        # ISO configurations for installation
        {
          "installer" = nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = {
              inherit inputs;
              hostname = "nixos";
              inherit (nixpkgs) lib;
            };
            modules = [ ./installer.nix ];
          };
        };

    };
}
