{ pkgs ? import <nixpkgs> {} }:
pkgs.stdenv.mkDerivation {
  name = "Jutlandia-Website";
  src = ./src;
  nativeBuildInputs = [ pkgs.emacs ];

  buildPhase = ''
    # Put a shell script here.
    HOME=/tmp/ emacs -Q --script export.el
    '';

  installPhase = ''
      mkdir -p $out;
      cp -r favicon.ico static/ $out/
      mv *.html $out/;
    '';
}
