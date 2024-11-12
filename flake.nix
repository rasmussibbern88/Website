{
  description = "Application packaged using poetry2nix";
  
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };
  
  outputs = { self, nixpkgs, flake-utils, poetry2nix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        # see https://github.com/nix-community/poetry2nix/tree/master#api for more functions and examples.
        myapp = { poetry2nix, lib }: poetry2nix.mkPoetryApplication {
          projectDir = self;
          overrides = poetry2nix.overrides.withDefaults (final: super:
            lib.mapAttrs
              (attr: systems: super.${attr}.overridePythonAttrs
                (old: {
                  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ map (a: final.${a}) systems;
                }))
              {
                # https://github.com/nix-community/poetry2nix/blob/master/docs/edgecases.md#modulenotfounderror-no-module-named-packagename
                # package = [ "setuptools" ];
              }
          );
        };
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            poetry2nix.overlays.default
            (final: _: {
              myapp = final.callPackage myapp { };
            })
          ];
        };
      in
        {
          app.default = {
            type = "app";
            # replace <script> with the name in the [tool.poetry.scripts] section of your pyproject.toml
            program = "${pkgs.myapp}/bin/run_site";
          };
          packages.default = pkgs.myapp;
          devShells = {
            # Shell for app dependencies.
            #
            #     nix develop
            #
            # Use this shell for developing your app.
            default = pkgs.mkShell {
              inputsFrom = [ pkgs.myapp ];
            };
            
            # Shell for poetry.
            #
            #     nix develop .#poetry
            #
            # Use this shell for changes to pyproject.toml and poetry.lock.
            poetry = pkgs.mkShell {
              packages = [ pkgs.poetry ];
            };
          };
          legacyPackages = pkgs;

          nixosModules.website = {config, pkgs, lib, ...}@args:
            with lib;
            let
              cfg = config.services.website;
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
                };
                
                config = mkIf cfg.enable {
                  systemd.services.website = {
                    description = "Jutlandia Website service";
                    after = [
                      "network.target"
                    ];
                    wantedBy = [ "multi-user.target" ];
                    environment = {
                      DISCORD_GUILD_ID = cfg.discordGuildId;
                      DISCORD_CLIENT_ID = cfg.discordClientId;
                      DISCORD_CLIENT_SECRET = cfg.discordClientSecret;
                      DISCORD_ADMIN_ROLE_ID = cfg.discordAdminRoleId;
                      DISCORD_REDIRECT_URI = cfg.discordRedirectUri;
                      
                      SQLALCHEMY_DATABASE_URI = cfg.databaseUrl;
                      APP_SECRET_KEY = cfg.appSecretKey;
                    };
                    serviceConfig = {
                      PermissionsStartOnly = true;
                      LimitNPROC = 512;
                      LimitNOFILE = 1048576;
                      NoNewPrivileges = true;
                      DynamicUser = true;
                      ExecStart = ''${pkgs.myapp}/bin/run_site'';
                      Restart = "on-failure";
                    };
                  };
                };
              };
        )
    };
}
