# oracle-nix

NixOS-образ для Oracle Cloud: `VM.Standard.A1.Flex` (Ampere, aarch64), QCOW2,
UEFI, paravirtualized. Собран из `nixos-unstable`.

## Что внутри

- SSH только по ключам, fail2ban, firewall.
- Tailscale (открыт UDP 41641).
- x-ui + Xray: панель на `:2053`; порты под inbounds 443/8080/8443 открыты
  (сами inbounds создаются в панели или импортом `x-ui.db`).
- Caddy: `:3443` → SearXNG, `:8091` → Zellij web.
- SearXNG (HTML + JSON API, слушает localhost).
- Zellij web + OpenCode server (для `ocv` с ноутбука).
- Docker, Go, Node, Bun, Python/uv, Jujutsu, micro, zellij, btop и прочий
  серверный набор с `riga-dev`.
- Zsh-алиасы из личного конфига (без GUI/десктопных).

Панель x-ui, Caddy и Zellij доступны **только через Tailscale**: их порты
закрыты файрволом на публичном интерфейсе.

## Установка через nixos-anywhere (рекомендуется)

Образ собирать не нужно. Берём свежий Oracle-инстанс с Ubuntu и ставим NixOS
поверх по SSH. **Disko сотрёт `/dev/sda`** — бекап boot volume обязателен,
если там что-то есть.

1. Создать instance: Ubuntu 24.04 Minimal **aarch64**, shape `VM.Standard.A1.Flex`,
   boot volume 50 GB, свой SSH-ключ.
2. На этом ПК:

```sh
cd ~/Projects/oracle-nix
direnv allow

KEXEC="$(nix build --print-out-paths \
  github:nix-community/nixos-images#packages.aarch64-linux.kexec-installer-nixos-unstable-noninteractive \
  )/nixos-kexec-installer-noninteractive-aarch64-linux.tar.gz"

nix run github:nix-community/nixos-anywhere -- \
  --flake .#oracle-anywhere \
  --target-host ubuntu@<PUBLIC_IP> \
  --kexec "$KEXEC" \
  --kexec-extra-flags "--kexec-syscall" \
  --build-on remote \
  --copy-host-keys
```

`--kexec-syscall` нужен именно на OCI Ubuntu-ядрах. `--build-on remote`
собирает систему на самом A1.Flex; если не получится — заменить на
`--build-on local` (будет медленно: aarch64 под эмуляцией).

3. Дождаться `### Done! ###`, затем:

```sh
ssh bongdo@<PUBLIC_IP>
sudo tailscale up
sudo git clone <repo> /etc/nixos
sudo nixos-rebuild switch --flake /etc/nixos#oracle
```

Так на сервер попадает полный конфиг (x-ui, Caddy, SearXNG, Docker, toolchain).
Проверено сообществом на OCI A1.Flex: см. `Gestao-de-Projeto/vps` и
`jesb1n/reborn.nix` (runbook для OCI ARM).

## Сборка образа (альтернатива)

Есть два образа:

- `qcow2-min` — bootstrap: только сеть, SSH, Tailscale. Лёгкий и собирается
  быстро. **Рекомендуется.**
- `qcow2` — сразу полный набор (x-ui, Caddy, SearXNG, Docker, toolchain).
  Тяжёлый: сборочная VM с 4 ГБ RAM, может упереться в память.

На хосте с Nix и включённой эмуляцией `aarch64-linux`
(`boot.binfmt.emulatedSystems = [ "aarch64-linux" ];` и
`extra-platforms = aarch64-linux` в `nix.conf`):

```sh
cd ~/Projects/oracle-nix
direnv allow
nix build .#qcow2-min -L
# → result/oracle-nixos-min.qcow2
```

Посмотреть план без сборки:

```sh
nix build .#qcow2-min --dry-run
nix eval .#nixosConfigurations.oracle-min.config.system.build.OCIImage.drvPath
```

## Импорт в Oracle Cloud

1. Загрузить `oracle-nixos-min.qcow2` в Object Storage (bucket в нужном регионе).
2. Compute → Custom Images → Import image:
   - Format: **QCOW2**
   - Launch mode: **Paravirtualized**
   - Firmware: **UEFI_64**
3. Создать instance из образа:
   - Shape: **VM.Standard.A1.Flex**
   - Boot volume: 50 GB (образ 8 GB, раздел растянется при загрузке)
   - SSH-ключ: добавить свой (он попадёт в `/root/.ssh/authorized_keys`)
4. В Security List / NSG открыть: `22`, `80`, `443`, `8080`, `8443`.
   Порт `41641/udp` — для Tailscale (если нужен прямой входящий).

После импорта в поле **Compatible Shapes** должен появиться
`VM.Standard.A1.Flex`; если его нет — образ собран не под aarch64 или выбран
BIOS вместо UEFI.

## Первый вход

```sh
ssh root@<public-ip>          # ключ из metadata
ssh bongdo@<public-ip>        # ключ зашит в конфиг
sudo tailscale up
```

В минимальном образе пока только SSH и Tailscale. Полный набор:

```sh
sudo git clone <repo> /etc/nixos
sudo nixos-rebuild switch --flake /etc/nixos#oracle
```

После этого админские сервисы — по tailnet-имени:

- `http://oracle:3443` — SearXNG
- `http://oracle:8091` — Zellij web
- `http://oracle:2053` — x-ui (на чистой БД `admin` / `admin`, сменить;
  после импорта `x-ui.db` — старые креды с riga)
- OpenCode: `ssh -L 4096:127.0.0.1:4096 bongdo@oracle`, пароль —
  `~/.config/opencode/server-password`.

Zellij web требует токен (тот же socket-dir, что у сервиса):

```sh
ZELLIJ_SOCKET_DIR=/home/bongdo/.cache/zellij-sockets zellij web --create-token
```

## Переезд state с riga-dev

Останавливать сервисы на riga не нужно, кроме x-ui (SQLite).

```sh
# x-ui: inbounds и клиенты
ssh riga-dev 'sudo systemctl stop x-ui && sudo cat /etc/x-ui/x-ui.db' > /tmp/x-ui.db
scp /tmp/x-ui.db oracle:/tmp/
ssh oracle 'sudo systemctl stop x-ui && sudo install -m 0600 -o root -g root /tmp/x-ui.db /var/lib/x-ui/x-ui.db && sudo systemctl start x-ui'

# opencode: настройки, команды, скиллы (пароль не переносим — сгенерится новый)
rsync -a --exclude server-password --exclude server.env \
  riga-dev:~/.config/opencode/ oracle:~/.config/opencode/

# проекты
rsync -a riga-dev:~/Projects/ oracle:~/Projects/
```

Hermes и VerstakERP в образ **не включены**: это приложения со своим state
и секретами. Их проще поднять отдельно, когда понадобятся:

- Hermes: flake `github:NousResearch/hermes-agent` + модуль
  `services.hermes-agent`; на aarch64 он тянет ~1200 сборочных зависимостей,
  поэтому в базовый образ не тащим.
- VerstakERP: собрать `server` под aarch64 и положить в
  `/var/lib/verstakerp/`; сервис добавить в `modules/services.nix`.

## Обновление конфига на сервере

```sh
ssh oracle
sudo git clone <repo> /etc/nixos      # или скопировать эту папку
sudo nixos-rebuild switch --flake /etc/nixos#oracle
```

Алиасы: `nix-switch`, `nix-update`, `nix-check`, `tailscale-on/off`, `ports`,
`logs`, `xui`.
