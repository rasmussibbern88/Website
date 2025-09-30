{
  description = "Jutlandia site using uv2nix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      pyproject-nix,
      uv2nix,
      pyproject-build-systems,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      forAllSystems = lib.genAttrs lib.systems.flakeExposed;

      workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };

      overlay = workspace.mkPyprojectOverlay {
        sourcePreference = "wheel";
      };

      editableOverlay = workspace.mkEditablePyprojectOverlay {
        root = "$REPO_ROOT";
      };

      pythonSets = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          python = pkgs.python3;
        in
        (pkgs.callPackage pyproject-nix.build.packages {
          inherit python;
        }).overrideScope
          (
            lib.composeManyExtensions [
              pyproject-build-systems.overlays.wheel
              overlay
            ]
          )
      );
      
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          pythonSet = pythonSets.${system}.overrideScope editableOverlay;
          virtualenv = pythonSet.mkVirtualEnv "jutlandia-site-dev-env" workspace.deps.all;
        in
        {
          default = pkgs.mkShell {
            packages = [
              virtualenv
              pkgs.uv
            ];
            env = {
              UV_NO_SYNC = "1";
              UV_PYTHON = pythonSet.python.interpreter;
              UV_PYTHON_DOWNLOADS = "never";
            };
            shellHook = ''
              unset PYTHONPATH
              export REPO_ROOT=$(git rev-parse --show-toplevel)
              . ${virtualenv}/bin/activate
            '';
          };
        }
      );

      packages = forAllSystems (system: {
        default = pythonSets.${system}.mkVirtualEnv "jutlandia-site-env" workspace.deps.default;
      });

    
    nixosModules.website = { config, pkgs, lib, ... }@args:
      with lib;
      let
        cfg = config.services.website;
        # Reference the package built for the system the module is running on
        jutlandia-site = self.packages.${pkgs.system}.default;
      in
      {
        options.services.website = {
          enable = mkEnableOption "Website service";
          databaseUrl = mkOption {
            type = types.str;
          };
          appSecretKey = mkOption {
            type = types.str;
          };
          discordClientSecret = mkOption {
            type = types.str;
          };
          discordClientId = mkOption {
            type = types.str;
          };
          discordGuildId = mkOption {
            type = types.str;
          };
          discordAdminRoleId = mkOption {
            type = types.str;
          };
          discordRedirectUri = mkOption {
            type = types.str;
          };
          infraClientSecret = mkOption {
            type = types.str;
          };
        };

        config = mkIf cfg.enable {
          systemd.services.website = {
            description = "Jutlandia Website service";
            after = [ "network.target" ];
            wantedBy = [ "multi-user.target" ];
            environment = {
              DISCORD_GUILD_ID = cfg.discordGuildId;
              DISCORD_CLIENT_ID = cfg.discordClientId;
              DISCORD_CLIENT_SECRET = cfg.discordClientSecret;
              DISCORD_ADMIN_ROLE_ID = cfg.discordAdminRoleId;
              DISCORD_REDIRECT_URI = cfg.discordRedirectUri;
              DISCORD_INFRA_CLIENT_SECRET = cfg.infraClientSecret;

              SQL_DB_URI = cfg.databaseUrl;
              APP_SECRET_KEY = cfg.appSecretKey;
            };
            serviceConfig = {
              PermissionsStartOnly = true;
              LimitNPROC = 512;
              LimitNOFILE = 1048576;
              NoNewPrivileges = true;
              DynamicUser = true;
              # This is the key change: point to the new package path
              ExecStart = "${jutlandia-site}/bin/run_site";
              Restart = "on-failure";
            };
          };
        };
      };
  };
}
