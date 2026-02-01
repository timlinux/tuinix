# Administrative user definition
{ config, lib, pkgs, ... }:

{
  # Administrative user account
  users.users.admin = {
    isNormalUser = true;
    description = "System Administrator";
    extraGroups = [ "wheel" "systemd-journal" "docker" ];
    home = "/home/admin";
    createHome = true;

    # SSH authorized keys
    openssh.authorizedKeys.keys = [
      # Add administrative SSH keys here
      # Example: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... admin@hostname"
    ];
    initialPassword = "admin";
  };

}
