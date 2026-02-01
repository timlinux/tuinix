# Default user user definition
{ config, lib, pkgs, ... }:

{
  # User account for user
  users.users.user = {
    isNormalUser = true;
    description = "user user";
    extraGroups = [ "wheel" "networkmanager" "audio" "video" ];

    # Home directory
    home = "/home/user";
    createHome = true;

    # SSH authorized keys (to be filled in by host configuration)
    openssh.authorizedKeys.keys = [
      # Add your SSH public keys here
      # Example: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... user@hostname"
    ];

    # Initial password (change on first login)
    # Use: mkpasswd -m sha-512 to generate a hashed password
    initialPassword = "changeme";
  };

}
