# Sound and Music package set -- console-only music creation studio
# A TUI subset of the Kartoza music production playground: algorithmic
# elevator music, MIDI composition, FluidSynth rendering, sox mastering
# and terminal live-coding tools. GUI tools (Sonic Pi, SuperCollider IDE,
# Pure Data, VCV Rack, Audacity, ...) are intentionally excluded.
{ config, lib, pkgs, ... }:

with lib;

let
  # Python environment for the generator scripts in ./music
  musicPython =
    pkgs.python3.withPackages (ps: with ps; [ numpy scipy psutil mido ]);

  soundfont = "${pkgs.soundfont-fluid}/share/soundfonts/FluidR3_GM2-2.sf2";

  # Gum menu (dotfile in ./music, deployed via wrapper -- no code in nix)
  musicMenu = pkgs.writeShellScriptBin "tuinix-music-menu" ''
    export MUSIC_PYTHON="${musicPython}/bin/python"
    export MUSIC_SCRIPTS="${./music}"
    export MUSIC_DIR="''${MUSIC_DIR:-$HOME/Music}"
    export SOUNDFONT="''${SOUNDFONT:-${soundfont}}"
    export MUSIC_TUI="${musicElevatorTui}/bin/tuinix-elevator-tui"
    exec ${pkgs.bash}/bin/bash ${./music/music-menu.sh} "$@"
  '';

  # Interactive elevator-music TUI (continuous mode)
  musicElevatorTui = pkgs.writeShellScriptBin "tuinix-elevator-tui" ''
    export ELEVATOR_MUSIC_PYTHON="${musicPython}/bin/python"
    export ELEVATOR_MUSIC_SCRIPT="${./music/enhanced_elevator_music.py}"
    exec ${pkgs.bash}/bin/bash ${./music/music_tui.sh} "$@"
  '';
in {
  config = mkIf config.tuinix.packages.music {
    environment.systemPackages = with pkgs; [
      # Entry points
      musicMenu
      musicElevatorTui

      # MIDI -> audio synthesis
      fluidsynth # scriptable MIDI renderer: fluidsynth -F out.wav
      soundfont-fluid # FluidR3 GM soundfont (fluidsynth needs one)
      timidity # alternative MIDI renderer

      # Procedural / generative / live-coding (console only)
      csound # venerable sound-and-score programming language
      chuck # strongly-timed audio programming language
      orca-c # esoteric livecoding sequencer, emits MIDI
      abcmidi # ABC notation -> MIDI (abc2midi and friends)

      # Audio plumbing / post-production
      ffmpeg # format conversion, ffplay playback
      sox # trim, fade, normalize, resample from CLI
      lame # mp3 encoding
      alsa-utils # aplay, amixer, alsamixer (TUI)

      # UI
      gum # TUI building blocks for the menus
    ];
    # Sound stack (PipeWire + wiremix) comes from the base set (minimal.nix)
  };
}
