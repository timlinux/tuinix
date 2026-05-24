# Default locale configuration
# Individual locale files (en_US.nix, pt_PT.nix) serve as templates
# that hosts can import directly to override these defaults.
{ lib, ... }:

{
  imports = [ ./en_US.nix ];
}
