# VM-specific configuration overrides
{ config, lib, ... }:

{
  # Disable ZFS for VMs (kernel compatibility issues)
  nixmywindows.zfs.enable = lib.mkForce false;
  
  # Disable problematic services for VMs
  services = {
    # Disable fail2ban in VMs
    fail2ban.enable = lib.mkForce false;
    
    # Disable TLP power management
    tlp.enable = lib.mkForce false;
    
    # Disable thermal management
    thermald.enable = lib.mkForce false;
    
    # Disable ACPI
    acpid.enable = lib.mkForce false;
  };
  
  # Simplify hardware detection for VMs
  hardware = {
    # Disable firmware
    enableAllFirmware = lib.mkForce false;
    
    # Disable microcode updates
    cpu.intel.updateMicrocode = lib.mkForce false;
    cpu.amd.updateMicrocode = lib.mkForce false;
  };
  
  # Networking tweaks for VMs
  networking = {
    # Use simpler network stack
    usePredictableInterfaceNames = lib.mkForce false;
    
    # Disable NetworkManager in VMs, use simpler networking
    networkmanager.enable = lib.mkForce false;
    
    # Enable DHCP
    useDHCP = lib.mkForce true;
  };
}