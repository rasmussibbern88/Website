{ pkgs ? import <nixpkgs> {}}:
with pkgs;
let
  application = p: p.callPackage ./default.nix {};
  pythonpkgs = python310.withPackages (p: with p; [
    black
    flask
    flask_sqlalchemy
    requests
  ]);
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    pythonpkgs
  ];
  shellHook = ''
    ##export FLASK_DEBUG=True
    export DISCORD_GUILD_ID=898896490343333909
    export DISCORD_CLIENT_ID=898897190091653161
    export DISCORD_CLIENT_SECRET=NH0D7fFVMRQ0rSoDTBmN-uG3hO6WTD6o
    export DISCORD_ADMIN_ROLE_ID=898900327452012574
    export DISCORD_REDIRECT_URI=http://localhost:5000/oauth
    export SQL_DB_URI="sqlite:///$(pwd)/jutlandia.db"
    echo $SQL_DB_URI
  '';
}
