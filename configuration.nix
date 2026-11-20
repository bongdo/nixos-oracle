# NixOS-сервер для Oracle Cloud (VM.Standard.A1.Flex, aarch64).
# Образ собирается модулем oci-image: QCOW2 + UEFI + virtio.
#
# Держим конфиг в одном месте; прикладной state (x-ui.db, ~/.config/opencode,
# проекты) сюда не коммитим — см. README.md.

{
  imports = [
    # /, /boot, GRUB, growPartition, virtio, сеть через networkd + OCI image.
    ./modules/oci-image.nix

    ./modules/overlays.nix
    ./modules/base.nix
    ./modules/packages.nix
    ./modules/services.nix
  ];

  # 20 GiB: с запасом под Nix store (toolchain + ffmpeg + clang).
  # При загрузке раздел растянется до размера boot volume.
  virtualisation.diskSize = 20 * 1024;

  system.stateVersion = "26.05";
}
