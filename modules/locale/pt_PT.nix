# Portuguese locale and keyboard configuration
{ config, lib, ... }:

{
  # Internationalization
  i18n = {
    defaultLocale = lib.mkDefault "pt_PT.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = lib.mkDefault "pt_PT.UTF-8";
      LC_IDENTIFICATION = lib.mkDefault "pt_PT.UTF-8";
      LC_MEASUREMENT = lib.mkDefault "pt_PT.UTF-8";
      LC_MONETARY = lib.mkDefault "pt_PT.UTF-8";
      LC_NAME = lib.mkDefault "pt_PT.UTF-8";
      LC_NUMERIC = lib.mkDefault "pt_PT.UTF-8";
      LC_PAPER = lib.mkDefault "pt_PT.UTF-8";
      LC_TELEPHONE = lib.mkDefault "pt_PT.UTF-8";
      LC_TIME = lib.mkDefault "pt_PT.UTF-8";
    };
  };

  # Console configuration
  console = {
    font = "Lat2-Terminus16";
    keyMap = "pt-latin1";
  };

  # Timezone (Portugal)
  time.timeZone = lib.mkDefault "Europe/Lisbon";

}
