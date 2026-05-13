{
  description = "HomeOps — Proxmox + k3s + Flux GitOps toolchain";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

  };

  outputs =
    inputs@{
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            terraform
            tflint
            kubectl
            kubernetes-helm
            helmfile
            kustomize
            fluxcd
            yq
            just
            direnv
            yamlfmt
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
          '';

        };
      }
    );
}
