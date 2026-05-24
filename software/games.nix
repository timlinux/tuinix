# Games package set -- best-of-breed terminal games across genres
{ config, lib, pkgs, ... }:

with lib;

{
  config = mkIf config.tuinix.packages.games {
    environment.systemPackages = with pkgs; [
      # Roguelikes
      angband # Classic Tolkien-themed dungeon crawler
      crawl # Dungeon Crawl Stone Soup - deep tactical roguelike
      cataclysm-dda # Post-apocalyptic survival roguelike

      # Puzzle games
      nudoku # Terminal sudoku
      greed # Eat as much as you can (number puzzle)
      bastet # Tetris clone that plays against you

      # Arcade / action
      nsnake # Classic snake game
      moon-buggy # Drive a buggy across the moon
      ninvaders # Space Invaders clone
      vitetris # Multiplayer terminal Tetris

      # Card and board games
      tty-solitaire # Klondike solitaire
      gnugo # GNU Go - play Go against the computer
      bsdgames # Collection of classic text games (adventure, worm, snake, etc.)

      # Text adventures
      frotz # Z-machine interpreter (play Zork and thousands of interactive fiction games)
      open-adventure # Colossal Cave Adventure - the original text adventure
    ];
  };
}
