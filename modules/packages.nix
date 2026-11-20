{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # shell / файлы
    bat
    btop
    curl
    fd
    file
    fzf
    git
    gh
    htop
    jq
    less
    lsof
    mosh
    ncdu
    ripgrep
    rsync
    screen
    tmux
    tree
    unzip
    wget
    yq-go
    zip
    zoxide

    # редакторы / терминал
    micro
    zellij

    # разработка
    bun
    clang-tools
    gcc
    gnumake
    go
    gnupg
    jujutsu
    nodejs
    openssl
    pkg-config
    python3
    uv

    # базы / сеть / утилиты
    docker-compose
    iperf3
    lazydocker
    libqalculate
    openiscsi
    qemu-utils
    qrencode
    sqlite-interactive

    # медиа / текст
    ffmpeg
    pandoc
    yt-dlp

    # инфраструктура, которую настраивают модули
    caddy
    searxng

    # локальные пакеты (overlay в configuration.nix)
    opencode
    x-ui
  ];
}
