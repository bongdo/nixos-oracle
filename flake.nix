{
  description = "NixOS server images for Oracle Cloud (Ampere A1, aarch64)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # OpenCode 2: в nixpkgs только V1, V2 берём из llm-agents.
    # Пакет ставит бинарь `opencode2`; в configuration.nix переименовываем.
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
    };

    # Только для установки через nixos-anywhere: разметка /dev/sda.
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      system = "aarch64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      full = self.nixosConfigurations.oracle;
      min = self.nixosConfigurations.oracle-min;

      fullImage = full.config.system.build.OCIImage;
      minImage = min.config.system.build.OCIImage;

      mkQcow2 =
        name: config: derivation:
        pkgs.runCommand name { } ''
          install -Dm644 ${derivation}/${config.image.filePath} $out/${name}.qcow2
        '';
    in
    {
      nixosConfigurations.oracle = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [ ./configuration.nix ];
      };

      # Bootstrap: SSH/Tailscale, без тяжёлого набора. Полный конфиг
      # накатывается на сервере нативно.
      nixosConfigurations.oracle-min = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [ ./configuration-min.nix ];
      };

      # Установка на живой Oracle-инстанс через nixos-anywhere.
      # Disko размечает /dev/sda, bootloader — GRUB/EFI.
      nixosConfigurations.oracle-anywhere = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [ ./configuration-anywhere.nix ];
      };

      # То же, но сразу с полным набором сервисов/пакетов.
      # Для повторной сборки на уже установленной системе.
      nixosConfigurations.oracle-anywhere-full = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [ ./configuration-full-anywhere.nix ];
      };

      packages.${system} = {
        # Каталоги с образами (внутри — qcow2 из make-disk-image).
        image = fullImage;
        image-min = minImage;

        # Плоские qcow2 — то, что заливается в Object Storage.
        qcow2 = mkQcow2 "oracle-nixos" full.config fullImage;
        qcow2-min = mkQcow2 "oracle-nixos-min" min.config minImage;

        default = self.packages.${system}.qcow2-min;
      };

      # Чтобы на x86-хосте работал короткий `nix build .#qcow2-min`.
      # Деривации всё равно aarch64 и собираются через binfmt.
      packages.x86_64-linux = {
        image = self.packages.${system}.image;
        image-min = self.packages.${system}.image-min;
        qcow2 = self.packages.${system}.qcow2;
        qcow2-min = self.packages.${system}.qcow2-min;
        default = self.packages.${system}.qcow2-min;
      };

      devShells.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
        packages = with nixpkgs.legacyPackages.x86_64-linux; [
          jq
          qemu-utils
        ];
      };

      devShells.aarch64-linux.default = pkgs.mkShell {
        packages = with pkgs; [
          jq
          qemu-utils
        ];
      };
    };
}
