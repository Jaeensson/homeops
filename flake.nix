{
  description = "HomeOps — Proxmox + k3s + Flux GitOps toolchain";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # nix-direnv for fast devShell activation via .envrc
    nix-direnv = {
      url = "github:nix-community/nix-direnv";
      flake = false;
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      flake-utils,
      nix-direnv,
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
            kustomize
            helmfile
            fluxcd
            yq
            just
            gettext
            openssh
          ];

          shellHook = ''
            # Source nix-direnv for fast re-activation
            if [ -f "${nix-direnv}/share/nix-direnv/direnvrc" ]; then
              source "${nix-direnv}/share/nix-direnv/direnvrc"
            fi

            echo "homeops devShell loaded"
            echo "  terraform  $(terraform --version | head -1)"
            echo "  kubectl    $(kubectl version --client --short 2>/dev/null || kubectl version --client 2>&1 | head -1)"
            echo "  helm       $(helm version --short)"
            echo "  helmfile   $(helmfile version)"
            echo "  flux       $(flux --version)"
            echo "  just       $(just --version)"
            echo "  yq         $(yq --version)"
          '';
        };
      }
    );
}
