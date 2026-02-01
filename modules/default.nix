# Main modules entry point
{ lib, ... }:

{
  imports = [ ./system ./security ./networking ];
}
