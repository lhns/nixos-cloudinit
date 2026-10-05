{ lib, pkgs, ... }: {
  # UEFI. The image build cannot write NVRAM, OVMF boots the fallback path instead.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  # Grow root after `qm resize`
  boot.growPartition = true;
  fileSystems."/".autoResize = true;

  # Serial console for the Proxmox serial terminal
  boot.kernelParams = [ "console=tty0" "console=ttyS0,115200" ];

  services.qemuGuest.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Users come from cloud-init (Proxmox ciuser) and are added to wheel.
  security.sudo.wheelNeedsPassword = lib.mkDefault false;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "@wheel" ]; # allows remote nixos-rebuild
  };

  # git is needed to switch to another flake
  environment.systemPackages = [ pkgs.git ];

  time.timeZone = lib.mkDefault "Europe/Berlin";
}
