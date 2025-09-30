# configuration.nix
{ config, lib, pkgs, ... }: {
  # customize kernel version
  boot.kernelPackages = pkgs.linuxPackages_5_15;
  
  users.groups.admin = {};
  users.users = {
    admin = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      password = "admin";
      group = "admin";
    };
  };

  services.website = {
    enable = true;
    databaseUrl = "YOUR_DATABASE_URL";
    appSecretKey = "YOUR_APP_SECRET_KEY";
    discordClientSecret = "YOUR_DISCORD_CLIENT_SECRET";
    discordClientId = "YOUR_DISCORD_CLIENT_ID";
    discordGuildId = "YOUR_DISCORD_GUILD_ID";
    discordAdminRoleId = "YOUR_DISCORD_ADMIN_ROLE_ID";
    discordRedirectUri = "YOUR_DISCORD_REDIRECT_URI";
    infraClientSecret = "YOUR_INFRA_CLIENT_SECRET";
  };


  virtualisation.vmVariant = {
    # following configuration is added only when building VM with build-vm
    virtualisation = {
      memorySize = 2048; # Use 2048MiB memory.
      cores = 3;
      graphics = false;
    };
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;
  };

  networking.firewall.allowedTCPPorts = [ 22 ];
  environment.systemPackages = with pkgs; [
    htop micro
  ];

  system.stateVersion = "23.05";

}
