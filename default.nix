{ pkgs ? import <nixpkgs> {} }:
pkgs.stdenv.mkDerivation {
  name = "Jutlandia-Website";
  src = ./src;
  nativeBuildInputs = [ pkgs.emacs ];

  buildPhase = ''
    # Put a shell script here.
    '';

  installPhase = ''
      mkdir -p $out;
      mv jutlandia-output/* $out/;
    '';
}
