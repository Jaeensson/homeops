{
  description = "HomeOps — Proxmox + k3s + Flux GitOps toolchain";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nix-flux-local.url = "github:Jaeensson/nix-flux-local";
    npm-package.url = "github:netbrain/npm-package";
  };

  outputs =
    inputs@{
      nixpkgs,
      flake-utils,
      nix-flux-local,
      npm-package,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [
            (final: prev: {
              flux-local = nix-flux-local.packages.${system}.flux-local;
            })
          ];
        };
      in
      {
        devShells.default = pkgs.mkShell {

          packages = with pkgs; [
            flux-local
            terraform
            tflint
            kubectl
            kubernetes-helm
            helmfile
            kustomize
            fluxcd
            yq-go
            just
            direnv
            yamlfmt
            renovate
            nodejs
            infisical
            minijinja
            (npm-package.lib.${system}.npmPackage {
              name = "pi";
              packageName = "@earendil-works/pi-coding-agent";
            })
          ];

          shellHook = ''
            echo "homeops devShell loaded"
            echo "  terraform  $(terraform --version | head -1)"
            echo "  kubectl    $(kubectl version --client 2>&1 | head -1)"
            echo "  helm       $(helm version --short)"
            echo "  helmfile   $(helmfile version -o short 2> /dev/null)"
            echo "  flux       $(flux --version)"
            echo "  just       $(just --version)" 
            echo "  yq         $(yq --version)"
            echo "  direnv     $(direnv version)"
            echo "  renovate   $(renovate --version)"
            echo "  pi         $(pi --version)"
            echo "  infisical  $(infisical --version)"
            echo "  minijinja  $(minijinja-cli -V)"
          '';

        };
      }
    );
}
