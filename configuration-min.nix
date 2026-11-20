# Минимальный bootstrap-образ: только загрузка, сеть, SSH, Tailscale.
# Полный набор сервисов/пакетов накатывается уже на сервере:
#   sudo nixos-rebuild switch --flake /etc/nixos#oracle
# Так сборочная VM не тащит 6.5 GiB store и не падает по памяти.

{ ... }:

{
  imports = [
    ./modules/oci-image.nix
    ./modules/base.nix
  ];

  system.stateVersion = "26.05";
}
