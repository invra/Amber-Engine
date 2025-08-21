{
  description = "Something something something something";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    naersk.url = "github:nix-community/naersk";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      rust-overlay,
      treefmt-nix,
      naersk,
      self,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };
        meta = with pkgs; {
          description = "Amber Engine";
          license = lib.licenses.unlicense;
          mainProgram = "ambere";
        };
        name = "amber";
        formatters =
          (treefmt-nix.lib.evalModule pkgs (_: {
            projectRootFile = ".git/config";
            programs = {
              nixfmt.enable = true;
              nixf-diagnose.enable = true;
              rustfmt.enable = true;
              toml-sort.enable = true;
            };
          })).config.build;
        naersk' = pkgs.callPackage naersk {
          cargo = pkgs.rust-bin.nightly.latest.default;
          rustc = pkgs.rust-bin.nightly.latest.default;
        };
        src = ./.;
      in
      with pkgs;
      {
        devShells.default = mkShell {
          inherit meta src;
          name = name + "-dev";
          nativeBuildInputs = [
            rust-bin.nightly.latest.default
            rustup
            rust-analyzer
            rustfmt
            clippy
          ] ++ lib.optional stdenv.isLinux [ valgrind ];

          shellHook =
            if !stdenv.isDarwin then
              ''
                #!/bin/bash
                $(awk -F: -v user=$USER 'user == $1 {print $NF}' /etc/passwd)
                exit
              ''
            else
              ''
                $(dscl . -read $HOME 'UserShell' | grep --only-matching '/.*')
                exit
              '';
        };

        packages.default = naersk'.buildPackage { inherit meta src; };
        formatter = formatters.wrapper;
        checks = {
          formatting = formatters.check self;
          cargo-test = naersk'.buildPackage {
            inherit meta src;
            doCheck = true;
          };
        };
      }
    );
}
