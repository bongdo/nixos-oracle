# Копия nixos/modules/virtualisation/oci-image.nix с memSize=8192.
# Причина: штатный oci-image собирает диск в VM с 1 GiB RAM, а наш closure
# (~6.5 GiB store) валится с "Cannot allocate memory" на nixos-install.
# Когда upstream сделает memSize настраиваемым — выкинуть этот файл.

{ config, lib, pkgs, modulesPath, ... }:

let
  cfg = config.oci;
in
{
  imports = [
    "${modulesPath}/virtualisation/oci-common.nix"
    "${modulesPath}/image/file-options.nix"
  ];

  config = {
    virtualisation.diskSize = lib.mkOverride 1490 (8 * 1024);
    virtualisation.diskSizeAutoSupported = false;

    system.nixos.tags = [ "oci" ];
    image.extension = "qcow2";

    system.build.OCIImage = import "${pkgs.path}/nixos/lib/make-disk-image.nix" {
      inherit config lib pkgs;
      inherit (config.virtualisation) diskSize;
      name = "oci-image";
      baseName = config.image.baseName;
      configFile = "${pkgs.path}/nixos/modules/virtualisation/oci-config-user.nix";
      format = "qcow2";
      partitionTableType = if cfg.efi then "efi" else "legacy";
      memSize = 8192;

      # Не тащим nixpkgs source в образ: на нём nixos-install внутри VM
      # упирается в readdir/ENOMEM (огромное дерево через virtiofs).
      # Канал не нужен: сервер обновляется флейком.
      copyChannel = false;
    };

    systemd.services.fetch-ssh-keys = {
      description = "Fetch authorized_keys for root user";

      wantedBy = [ "sshd.service" ];
      before = [ "sshd.service" ];

      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      path = [
        pkgs.coreutils
        pkgs.curl
      ];
      script = ''
        mkdir -m 0700 -p /root/.ssh
        if [ -f /root/.ssh/authorized_keys ]; then
          echo "Authorized keys have already been downloaded"
        else
          echo "Downloading authorized keys from Instance Metadata Service v2"
          curl -s -S -L \
            -H "Authorization: Bearer Oracle" \
            -o /root/.ssh/authorized_keys \
            http://169.254.169.254/opc/v2/instance/metadata/ssh_authorized_keys
          chmod 600 /root/.ssh/authorized_keys
        fi
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        StandardError = "journal+console";
        StandardOutput = "journal+console";
      };
    };
  };
}
