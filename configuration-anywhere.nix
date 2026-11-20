# Конфиг для установки на живой Oracle-инстанс через nixos-anywhere.
# Не используется для сборки образа: тут нет oci-image, диск размечает disko.
# После установки полный конфиг накатывается с ./configuration.nix.

{ inputs, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
    inputs.disko.nixosModules.disko

    ./modules/base.nix
    ./modules/disko.nix
  ];

  system.stateVersion = "26.05";

  networking.useNetworkd = true;
  networking.useDHCP = true;

  services.qemuGuest.enable = true;

  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  boot.loader.efi.canTouchEfiVariables = false;
}
