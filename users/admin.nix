# Administrative user definition
{ config, lib, pkgs, ... }:

{
  # Administrative user account.
  # The account ships LOCKED (no password): a default password like
  # "admin" on a wheel user is a remote/local takeover waiting to
  # happen. Unlock it by adding SSH keys below or setting a
  # hashedPassword, then rebuild.
  users.users.admin = {
    isNormalUser = true;
    description = "System Administrator";
    extraGroups = [ "wheel" "systemd-journal" ];
    home = "/home/admin";
    createHome = true;

    # SSH authorized keys
    openssh.authorizedKeys.keys = [
      # Add administrative SSH keys here
      # Example: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... admin@hostname"
    ];
  };

}
