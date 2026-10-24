# WtfLinux

> Una distro Linux rolling-release construida con GitHub Actions, kernel CachyOS
> y bootstrap estilo LFS. Dos variantes en paralelo: **pacman + systemd** y
> **xbps + runit**. ISO lista para arrancar, con `nano`, `grub`, `soar`,
> `i3wm + lightdm`, `linux-firmware` completo y herramientas de build / red / sistema.

[![Build Kernel](https://img.shields.io/badge/build--kernel-compile%20cachy-blue)](.github/workflows/build-kernel.yml)
[![Build ISO](https://img.shields.io/badge/build--iso-pacman%20%2B%20xbps-purple)](.github/workflows/build-iso.yml)

---

## ✨ Características

| Variante | Gestor | Init | Bootstrap | HF prefix |
|----------|--------|------|-----------|-----------|
| `pacman` | `pacman` (Arch) | systemd | pacstrap | `pacman-systemd-…` |
| `xbps`   | `xbps` (Void)   | runit | `xbps-install --root` | `xbps-runit-…` |

- **Kernel CachyOS** compilado desde `CachyOS/linux-cachyos` (rama `master`),
  con config BORE, EEVDF, Hz 1000, PREEMPT, módulos zstd, debug apagado.
- **Software preinstalado**: `nano`, `grub`, `soar` (pkgforge), `i3-wm`,
  `lightdm`, `linux-firmware`, `intel-ucode`, `amd-ucode`, `NetworkManager`,
  `dhclient`, `wpa_supplicant`, `iwd`, `htop`, `btop`, `ncdu`, `ripgrep`, `fd`,
  `fastfetch`, `base-devel`, `gcc`, `make`, `cmake`, `git`, `curl`, `wget`.
- **`/etc/os-release`** dice `NAME="WtfLinux"`, `ID=wtflinux`, `VARIANT=pacman-systemd`
  o `xbps-runit`.
- **ISO híbrida** (BIOS + EFI) con grub-mkrescue + xorriso.
- **Upload automático** al dataset `arepaconcafe/wtflinux` de Hugging Face.

## 🗂 Estructura del repo

```
wtflinux/
├── .github/workflows/
│   ├── build-kernel.yml      # Compila kernel Cachy y publica release
│   └── build-iso.yml         # Matriz pacman+systemd / xbps+runit → ISO
├── scripts/lfs/
│   ├── lib/common.sh         # Funciones compartidas (log, chroot, etc.)
│   ├── 00-bootstrap-pacman.sh
│   ├── 00-bootstrap-xbps.sh
│   ├── 01-fetch-kernel.sh    # Descarga kernel del último release
│   ├── 02-install-kernel.sh  # Extrae kernel al rootfs
│   ├── 04-install-packages.sh
│   ├── install-soar.sh        # Baja binario de pkgforge/soar
│   ├── 05-config-system.sh    # os-release, hostname, locale, motd
│   ├── 06-config-grub.sh      # grub.cfg de la ISO
│   ├── 07-config-init.sh      # systemctl / runit sv
│   ├── 08-config-desktop.sh   # i3 + lightdm + autologin
│   ├── 09-mkinitramfs.sh      # mkinitcpio / dracut
│   ├── 10-mksquashfs.sh       # squashfs del rootfs
│   └── 11-build-iso.sh        # xorriso + grub-mkrescue
└── config/
    ├── os-release.pacman
    ├── os-release.xbps
    ├── packages-pacman.list
    ├── packages-xbps.list
    ├── hostname
    ├── grub/grub.cfg
    ├── lightdm/lightdm.conf
    ├── i3/config
    ├── dracut/wtflinux.conf
    └── mkinitcpio/mkinitcpio.conf
```

## 🚀 Uso

### 1. Configurar secretos

En tu repo de GitHub → `Settings → Secrets and variables → Actions`:

- `HF_TOKEN`: token de Hugging Face con permiso **write** sobre el dataset
  `arepaconcafe/wtflinux`.

El `GITHUB_TOKEN` se inyecta automáticamente.

### 2. Compilar el kernel (una vez)

`Actions → Compile WtfLinux Cachy Kernel → Run workflow`

- Default: rama `master` de CachyOS/linux-cachyos
- Output: release con tag `kernel-<KVER>` que contiene
  `wtflinux-cachy-kernel-<KVER>.tar.gz` + `kernel-release.txt`.

### 3. Compilar la ISO

`Actions → Build WtfLinux ISO → Run workflow`

- Inputs:
  - `kernel_tag`: tag del release del kernel. Default `latest`.
  - `upload_to_hf`: `true` (subir a Hugging Face) o `false`.
- Output:
  - 2 artefactos (uno por variante): `WtfLinux-<pkgmgr>-<run_id>`
  - 2 ISOs en `arepaconcafe/wtflinux` en HF:
    - `pacman-systemd-WtfLinux-pacman-systemd-<date>.iso`
    - `xbps-runit-WtfLinux-xbps-runit-<date>.iso`
  - 2 archivos `*-sha256.txt` con sus hashes.

### 4. Probar la ISO

```bash
# QEMU
qemu-system-x86_64 -enable-kvm -m 2G -cdrom WtfLinux-pacman-systemd-*.iso

# Booteable desde USB con dd o Ventoy
sudo dd if=WtfLinux-xbps-runit-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Login live: **`anon` / `anon`** (sudo sin password) o **`root` / `root`**.

## 🧱 Cómo funciona la build

```
┌──────────────────────┐        ┌───────────────────────────┐
│  build-kernel.yml    │        │  build-iso.yml             │
│  (Void container)    │        │  (matrix: pacman / xbps)   │
│                      │        │                             │
│  1. xbps-install -Sy │        │  3a. pacstrap  → ROOTFS/    │
│     base-devel …     │        │  3b. xbps-install --root   │
│  2. clone CachyOS    │        │      -r ROOTFS base-system │
│  3. cp config         │        │  4. download kernel tar.gz │
│  4. apply patches     │        │     from releases          │
│  5. make bzImage      │  ───►  │  5. tar xzf into ROOTFS    │
│     modules           │  pull  │  6. install extra packages │
│  6. tar -czf          │  rel.  │  7. install soar           │
│     wtflinux-cachy-   │        │  8. config os-release       │
│     kernel-KVER.tar.gz│        │     → NAME=WtfLinux        │
│  7. publish release   │        │  9. enable services        │
│     kernel-KVER       │        │     (systemctl / ln -s sv) │
└──────────────────────┘        │ 10. config i3 + lightdm     │
                                 │ 11. mkinitramfs            │
                                 │     (mkinitcpio / dracut)   │
                                 │ 12. mksquashfs ROOTFS       │
                                 │ 13. xorriso + grub-mkrescue│
                                 │ 14. sha256sum               │
                                 │ 15. hf upload arepaconcafe/│
                                 │     wtflinux                │
                                 └─────────────────────────────┘
```

## 🔧 Personalización rápida

- **Listas de paquetes**: edita `config/packages-pacman.list` y
  `config/packages-xbps.list`. Una línea por paquete, `#` para comentarios.
- **i3 config**: edita `config/i3/config` (se copia a `/etc/skel/.config/i3/`).
- **lightdm**: edita `config/lightdm/lightdm.conf`.
- **os-release**: edita `config/os-release.pacman` o `config/os-release.xbps`.
  El script `05-config-system.sh` regenera algunas líneas (BUILD_ID, VARIANT)
  sobre la plantilla.
- **Kernel tweaks**: en `.github/workflows/build-kernel.yml` paso 6, edita los
  `scripts/config` calls (Hz, preempt, debug, módulos, etc.).
- **Repos xbps**: cambia `XBPS_REPO` en `00-bootstrap-xbps.sh` para usar otro
  mirror (default `https://repo-de.voidlinux.org/current`).

## ⚠️ Limitaciones conocidas

- La ISO live **NO persiste** cambios entre reinicios. Para persistencia real,
  instala WtfLinux a disco con `pacstrap` o `void-installer` desde el live.
- `nvidia-dkms` está en la lista pacman pero el DKMS necesita los headers del
  kernel (instalados por separado). Si falla el build, coméntalo.
- El workflow corre en `ubuntu-latest` con `--privileged` (necesario para
  `mksquashfs` y `enter_chroot`). En runners self-hosted también funciona.
- Tiempos aproximados:
  - `build-kernel.yml`: 60–90 min (depende del `-jN` del runner)
  - `build-iso.yml`: 25–40 min por variante (corren en paralelo)

## 📦 Descarga directa

Las ISOs se publican en:
- Hugging Face dataset: `https://huggingface.co/datasets/arepaconcafe/wtflinux`
- GitHub Releases del kernel: `https://github.com/<tu-usuario>/<tu-repo>/releases`

## 🤝 Créditos

- Kernel: [CachyOS/linux-cachyos](https://github.com/CachyOS/linux-cachyos)
- Bootstrap pacman: [archlinux](https://archlinux.org/) + pacstrap
- Bootstrap xbps: [Void Linux](https://voidlinux.org/) + xbps
- Soar: [pkgforge/soar](https://github.com/pkgforge/soar)
- Inspiration: tus workflows `Compilar Neko Void Kernel` ✨

---

WtfLinux — porque "menos es más, pero raro es mejor".
