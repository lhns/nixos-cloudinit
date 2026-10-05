{ lib, ... }: {
  # nix build .#image writes qcow2 (main.qcow2) instead of raw
  disko.imageBuilder.imageFormat = "qcow2";

  disko.devices.disk.main = {
    type = "disk";
    # Only used when formatting (nixos-anywhere). The booted system mounts by
    # partition label, so sda (VirtIO SCSI) vs vda (VirtIO Block) does not matter.
    device = lib.mkDefault "/dev/sda";
    imageSize = "8G"; # template size; clones get resized in Proxmox
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
