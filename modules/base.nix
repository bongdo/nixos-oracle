{ pkgs, ... }:

{
  # ── Nix ─────────────────────────────────────────────────────────────────────
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      "bongdo"
    ];
    auto-optimise-store = true;
  };

  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
  };
  nix.optimise.automatic = true;

  nixpkgs.config.allowUnfree = true;

  # ── Boot / виртуалка ────────────────────────────────────────────────────────
  boot.loader.grub.configurationLimit = 3;
  boot.tmp.cleanOnBoot = true;
  services.qemuGuest.enable = true;

  # ── Локаль / время ──────────────────────────────────────────────────────────
  time.timeZone = "Europe/Moscow";
  i18n.defaultLocale = "en_US.UTF-8";

  # ── Сеть ────────────────────────────────────────────────────────────────────
  networking.hostName = "oracle";

  # Публичные порты: SSH и inbounds xray. Всё админское — только через tailnet.
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22
      80
      443
      8080
      8443
    ];
    interfaces."tailscale0".allowedTCPPorts = [
      2053 # x-ui panel
      3443 # Caddy -> SearXNG
      8084 # Zellij web
      8091 # Caddy -> Zellij web
      8888 # SearXNG
    ];
    # mosh
    allowedUDPPortRanges = [
      {
        from = 60000;
        to = 61000;
      }
    ];
  };

  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

  # ── SSH / доступ ────────────────────────────────────────────────────────────
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
      X11Forwarding = false;
    };
  };

  security.sudo.wheelNeedsPassword = false;

  services.fail2ban = {
    enable = true;
    maxretry = 4;
    bantime = "1h";
    ignoreIP = [
      "127.0.0.1/8"
      "::1"
      "100.64.0.0/10" # tailnet
    ];
  };

  users.mutableUsers = false;

  # Root-ключ приходит из OCI metadata (сервис oci-image). Не задаём его здесь:
  # иначе файл уже существует и metadata-ключ не скачается.
  # bongdo — свой ключ, чтобы вход был даже при сбое metadata.
  users.users.bongdo = {
    isNormalUser = true;
    description = "bongdo";
    extraGroups = [
      "wheel"
      "users"
    ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIWdbT2gVgBcPDqb7o3U19tKf89AVuzj25dAivnsK4uB bongdo@nixos"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDHOLIW10V85Og75oFAPnh+Cz/RHftU2aSbNGmCjMSRC bongdo@nixos"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDGQ7YDoFNcnTOy7ucCUq5i3qlnkWudAA1IIuJbWDopV riga-dev->frankfurt"
    ];
  };

  # ── Shell ───────────────────────────────────────────────────────────────────
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    histSize = 100000;

    shellAliases = {
      # базовое
      logout = "loginctl terminate-user $USER";
      cat = "bat";
      grep = "rg";
      ff = "fastfetch";
      disk-analyzer = "ncdu";
      docker-manager = "lazydocker";
      o = "opencode";
      oo = "opencode";
      sq = "sqlite3";
      ll = "ls -lhv --group-directories-first";
      la = "ls -lAhv --group-directories-first";
      mkdir = "mkdir -p";
      size = "du -sh";
      myip = "curl -s ifconfig.me && echo";
      h = "alias | grep -v '^_' | sed 's/=/  ➔  /' | bat --language=bash --plain";
      help = "h";
      ".." = "cd ..";
      "..." = "cd ../..";

      # nix / сервер
      nix-switch = "sudo nixos-rebuild switch --flake /etc/nixos#oracle";
      nix-update = "sudo nix flake update /etc/nixos && sudo nixos-rebuild switch --flake /etc/nixos#oracle";
      nix-check = "sudo nixos-rebuild build --flake /etc/nixos#oracle";
      tailscale-on = "sudo systemctl start tailscaled && sudo tailscale up";
      tailscale-off = "sudo tailscale down; sudo systemctl stop tailscaled";
      ports = "ss -tlnp";
      logs = "journalctl -f";
      xui = "sudo systemctl status x-ui --no-pager";
    };
  };

  programs.starship.enable = true;
  programs.zoxide.enable = true;
  programs.fzf = {
    keybindings = true;
    fuzzyCompletion = true;
  };
  programs.bat.enable = true;
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  environment.sessionVariables = {
    EDITOR = "micro";
    VISUAL = "micro";
    PAGER = "less";
  };

  # Ghostty шлёт TERM=xterm-ghostty. Без этого terminfo zsh/ZLE
  # ломает удаление/перерисовку строки на сервере.
  # Кладём в ~/.terminfo: /etc/terminfo/x — симлинк на read-only ncurses.
  systemd.tmpfiles.rules = [
    "d /home/bongdo/.terminfo 0755 bongdo users - -"
    "d /home/bongdo/.terminfo/x 0755 bongdo users - -"
    "C /home/bongdo/.terminfo/x/xterm-ghostty 0644 bongdo users - ${./xterm-ghostty}"
  ];

  services.journald.settings.Journal.SystemMaxUse = "500M";
}
