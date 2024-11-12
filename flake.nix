{
  description = "Application packaged using poetry2nix";
  
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  
  outputs = { self, nixpkgs, poetry2nix }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      inherit (poetry2nix.lib.mkPoetry2Nix {inherit pkgs;}) mkPoetryApplication;
      jutlandia-site = mkPoetryApplication {projectDir = ./.;};
    in
      {
        apps.${system}.default = {
          type = "app";
          # replace <script> with the name in the [tool.poetry.scripts] section of your pyproject.toml
          program = "${jutlandia-site}/bin/run_site";
        };
        packages.${system}.default = jutlandia-site;
        devShells.${system} = {
          # Shell for app dependencies.
          #
          #     nix develop
          #
          # Use this shell for developing your app.
          default = pkgs.mkShell {
            inputsFrom = [ jutlandia-site ];
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
                    
                    SQL_DB_URI = cfg.databaseUrl;
                    APP_SECRET_KEY = cfg.appSecretKey;
                  };
                  serviceConfig = {
                    PermissionsStartOnly = true;
                    LimitNPROC = 512;
                    LimitNOFILE = 1048576;
                    NoNewPrivileges = true;
                    DynamicUser = true;
                    ExecStart = ''${jutlandia-site}/bin/run_site'';
                    Restart = "on-failure";
                  };
                };
              };
            };
      };
}
