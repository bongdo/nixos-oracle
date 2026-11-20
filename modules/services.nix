{ lib, pkgs, ... }:

{
  # ── Caddy: reverse proxy для tailnet-сервисов ───────────────────────────────
  # Наружу порты не открыты (см. base.nix); доступ только через tailscale0.
  services.caddy = {
    enable = true;
    configFile = ./caddy/Caddyfile;
  };

  # ── SearXNG ────────────────────────────────────────────────────────────────
  services.searx = {
    enable = true;
    environmentFile = "/var/lib/searx/searx.env";
    settings = {
      use_default_settings = true;
      general.instance_name = "oracle";
      server = {
        bind_address = "127.0.0.1";
        port = 8888;
        secret_key = "$SEARX_SECRET_KEY";
        base_url = false;
        limiter = false;
        image_proxy = false;
      };
      search = {
        formats = [
          "html"
          "json"
        ];
        safe_search = 0;
        autocomplete = "";
        default_lang = "auto";
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/searx 0700 searx searx - -"
    "f /var/lib/searx/searx.env 0600 searx searx - SEARX_SECRET_KEY=62b1f1357fddd428708673c89b8913ff5aa70ff32759b9f139fa103eb60dd8b0"
  ];

  # ── x-ui + xray ────────────────────────────────────────────────────────────
  # x-ui сам управляет xray (бинд 443/8080/8443) и хранит inbounds в SQLite.
  # Панель слушает 2053, наружу закрыта: только tailscale0.
  systemd.services.x-ui = {
    description = "3x-ui panel and Xray";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    environment = {
      XUI_DB_FOLDER = "/var/lib/x-ui";
      XUI_LOG_FOLDER = "/var/log/x-ui";
      XUI_BIN_FOLDER = "/var/lib/x-ui/bin";
    };

    preStart = ''
      ${pkgs.coreutils}/bin/install -d -m 0755 /var/lib/x-ui/bin
      # -n: не перетирать xray/geo-базы, обновлённые из панели.
      ${pkgs.coreutils}/bin/cp -rn ${pkgs.x-ui}/lib/x-ui/bin/. /var/lib/x-ui/bin/
      ${pkgs.coreutils}/bin/chmod 0755 /var/lib/x-ui/bin/xray-linux-arm64
    '';

    serviceConfig = {
      Type = "simple";
      WorkingDirectory = "/var/lib/x-ui";
      ExecStart = "${pkgs.x-ui}/bin/x-ui";
      Restart = "on-failure";
      RestartSec = 5;

      StateDirectory = "x-ui";
      LogsDirectory = "x-ui";

      AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
      CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      ReadWritePaths = [
        "/var/lib/x-ui"
        "/var/log/x-ui"
      ];
    };
  };

  # ── Zellij web ─────────────────────────────────────────────────────────────
  environment.etc."zellij/config.kdl".source = ./zellij/config.kdl;
  environment.etc."zellij/layouts/minimal.kdl".source = ./zellij/layouts/minimal.kdl;
  environment.etc."zellij/themes/everforest.kdl".source = ./zellij/themes/everforest.kdl;

  systemd.services.zellij-web = {
    description = "Zellij web terminal";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    environment = {
      HOME = "/home/bongdo";
      PATH = lib.mkForce "/run/current-system/sw/bin:/run/wrappers/bin";
      EDITOR = "micro";
      VISUAL = "micro";
      ZELLIJ_CONFIG_DIR = "/etc/zellij";
      ZELLIJ_SOCKET_DIR = "/home/bongdo/.cache/zellij-sockets";
    };

    serviceConfig = {
      Type = "simple";
      User = "bongdo";
      Group = "users";
      WorkingDirectory = "/home/bongdo";
      ExecStartPre = "${pkgs.coreutils}/bin/install -d -m 0700 /home/bongdo/.cache/zellij-sockets";
      ExecStart = "${pkgs.zellij}/bin/zellij --config /etc/zellij/config.kdl web --start";
      Restart = "always";
      RestartSec = 3;

      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = false;
    };
  };

  # ── OpenCode server ────────────────────────────────────────────────────────
  # Слушает 127.0.0.1:4096. Пароль генерится на первом старте в
  # ~/.config/opencode/server-password — его же читает alias ocv с ноутбука.
  systemd.services.opencode-serve = {
    description = "OpenCode server";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    wants = [ "network.target" ];

    environment = {
      HOME = "/home/bongdo";
      PATH = lib.mkForce "/run/current-system/sw/bin:/run/wrappers/bin";
    };

    preStart = ''
      ${pkgs.coreutils}/bin/install -d -m 0700 /home/bongdo/.config/opencode
      if [ ! -s /home/bongdo/.config/opencode/server-password ]; then
        (umask 077; ${pkgs.openssl}/bin/openssl rand -hex 32 > /home/bongdo/.config/opencode/server-password)
      fi
    '';

    serviceConfig = {
      Type = "simple";
      User = "bongdo";
      Group = "users";
      WorkingDirectory = "/home/bongdo";
      ExecStart = pkgs.writeShellScript "opencode-serve" ''
        export OPENCODE_PASSWORD="$(${pkgs.coreutils}/bin/cat /home/bongdo/.config/opencode/server-password)"
        exec ${pkgs.opencode}/bin/opencode serve --hostname 127.0.0.1 --port 4096
      '';
      Restart = "always";
      RestartSec = 5;

      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = false;
    };
  };

  # ── Docker ─────────────────────────────────────────────────────────────────
  virtualisation.docker.enable = true;
  users.users.bongdo.extraGroups = [ "docker" ];
}
