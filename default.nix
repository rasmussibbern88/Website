{ nixpkgs ? (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/ba02fd0434ed92b7335f17c97af689b9db1413e0.tar.gz";
    sha256 = "1pjx78qb3k4cjkbwiw9v0wd545h48fj4criazijwds53l0q4dzn1";
})}:
let
  pkgs = import nixpkgs {};
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

  pythonCatchConflictsPhase = "";
  #pythonImportsCheck = [ "jutlandia_site"];
}
