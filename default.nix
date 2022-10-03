{ pkgs ? import <nixpkgs> {}}:
let
  pythonpkgs = pkgs.python310.withPackages (p: with p; [
    flask
    flask_sqlalchemy
    requests
  ]);
in
with pkgs.python310Packages;
buildPythonPackage {
  name = "jutlandia_site";
  version = "1.0";
  src = ./.;
  format = "pyproject";

  propagatedBuildInputs = [ pythonpkgs ];
  nativeBuildInputs = [ setuptools-scm ];

  doCheck = false;
  #pythonImportsCheck = [ "jutlandia_site"];
}
