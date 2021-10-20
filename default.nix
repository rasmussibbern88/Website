{ pkgs ? import <nixpkgs> {} }:
pkgs.stdenv.mkDerivation {
  name = "Jutlandia-Website";
  src = ./src;
  nativeBuildInputs = [ pkgs.emacs ];

  buildPhase = ''
    # Put a shell script here.
    emacs -Q --script export.el
    '';

  installPhase = ''
      mkdir -p $out;
      mv *.html $out/;
    '';
}
