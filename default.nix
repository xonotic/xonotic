{ pkgs ? import <nixpkgs> {}, cc ? null }@args:
pkgs.callPackage ./derivation.nix args
