# nixos-cloudinit

A generic NixOS image for Proxmox VE. The disk layout is declared once with
[disko](https://github.com/nix-community/disko). Per-VM identity (hostname, IP, user,
SSH keys) comes from **Proxmox cloud-init**. CI builds the image as a qcow2 and attaches it
to each release.

The image is deliberately minimal. Your own (possibly private) flake imports
`nixosModules.default` and adds the rest. You switch a VM to it once, after first boot.

## Who owns what

| Concern | Owner |
|---|---|
| Partitions, filesystems | `disko.nix` (ESP + ext4 root, mounted by partition label) |
| Boot, SSH, qemu guest agent, Nix flakes, sudo | `modules/base.nix` |
| Hostname, IP, gateway, DNS, user, SSH keys, password | Proxmox cloud-init |
| Everything else | your flake on top |

Details:

- **Boot:** UEFI only (OVMF + systemd-boot), and Secure Boot must be off.
- **Users:** the user comes from `ciuser`, in groups `wheel` (passwordless sudo) and `docker`. The `docker` group is pre-created with NixOS's fixed gid, so a derived config that enables Docker works without re-provisioning the user.
- **Root:** password and SSH login are both off.

## Create the Proxmox template

```sh
mkdir -p /var/lib/vz/import
wget -O /var/lib/vz/import/nixos-cloudinit.qcow2 \
  https://github.com/lhns/nixos-cloudinit/releases/latest/download/nixos-cloudinit-x86_64-linux.qcow2

qm create 9000 --name nixos-cloudinit --ostype l26 \
  --machine q35 --bios ovmf \
  --efidisk0 local-lvm:1,efitype=4m,pre-enrolled-keys=0 \
  --cpu host --cores 2 --memory 4096 \
  --scsihw virtio-scsi-single \
  --scsi0 local-lvm:0,import-from=/var/lib/vz/import/nixos-cloudinit.qcow2,discard=on,ssd=1,iothread=1 \
  --ide2 local-lvm:cloudinit \
  --boot order=scsi0 \
  --net0 virtio,bridge=vmbr0 \
  --agent enabled=1 \
  --serial0 socket --vga serial0

qm template 9000
```

Notes on these options:

- **`pre-enrolled-keys=0`** turns Secure Boot off. Otherwise OVMF refuses the unsigned systemd-boot.
- **`--vga serial0`** puts the console on the Proxmox serial terminal. Drop it if you prefer noVNC.
- **Never boot the template itself.** Every clone generates its own SSH host keys and machine-id on first boot.

## Deploy a VM

```sh
qm clone 9000 111 --name myvm --full
qm set 111 --ciuser me --sshkeys ~/.ssh/id_ed25519.pub --ipconfig0 ip=dhcp
qm resize 111 scsi0 32G
qm start 111
```

For a static address, use `--ipconfig0 ip=10.0.10.11/24,gw=10.0.10.1 --nameserver 10.0.10.1`
instead of `ip=dhcp`.

Then on the VM:

```sh
cloud-init status --long   # done, no errors
hostnamectl                # the VM name
df -h /                    # grown to the resized disk
id                         # wheel, docker
```

## Your own flake on top

```nix
{
  inputs = {
    nixos-cloudinit.url = "github:lhns/nixos-cloudinit";
    nixpkgs.follows = "nixos-cloudinit/nixpkgs";
  };

  outputs = { nixpkgs, nixos-cloudinit, ... }: {
    nixosConfigurations.myvm = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        nixos-cloudinit.nixosModules.default   # same disk layout, boot, cloud-init
        ({ ... }: {
          virtualisation.docker.enable = true;
          system.stateVersion = "26.05";
        })
      ];
    };
  };
}
```

Switch a VM to it. If the repo is private, forward your SSH agent (`ssh -A`). The fetch runs as
your user, so nothing secret is stored on the VM:

```sh
nixos-rebuild switch --sudo --flake git+ssh://git@github.com/you/your-flake#myvm
```

You can also push from any machine with Nix:

```sh
nixos-rebuild switch --flake .#myvm --target-host me@10.0.10.11 --sudo
```

## Reinstall with nixos-anywhere

This covers VMs that weren't created from the template, and bare metal. It uses the same layout:

```sh
nix run github:nix-community/nixos-anywhere -- --flake .#myvm --target-host root@10.0.10.50
```

disko wipes the disk named in `disko.nix` (`/dev/sda` by default). Override
`disko.devices.disk.main.device` in your flake if needed.

## Build locally

```sh
nix build .#image   # result/main.qcow2, needs /dev/kvm
```

Without local Nix, run this in the `nixos/nix` container with `--privileged --device /dev/kvm`
and `system-features = kvm nixos-test benchmark big-parallel`.

## Gotchas

- **Secure Boot** must be off (`pre-enrolled-keys=0`).
- **`system.stateVersion`** stays at the release you first installed, even after you bump `nixpkgs`.
- **cloud-init runs once per instance.** A user created on first boot is not changed by later
  `nixos-rebuild` runs, and it is not removed either: `users.mutableUsers` stays on.
- **The guest agent** needs both `services.qemuGuest.enable` (set here) and `--agent enabled=1` on the VM.
