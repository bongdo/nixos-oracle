# Полный набор сервисов для системы, установленной через nixos-anywhere+disko.
# Не импортирует oci-common: fileSystems берутся из disko (by-partlabel).

{ inputs, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
    inputs.disko.nixosModules.disko

    ./modules/overlays.nix
    ./modules/disko.nix
    ./modules/base.nix
    ./modules/packages.nix
    ./modules/services.nix
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
