{ config, lib, ... }: {
  # Empty hostname: set at runtime by cloud-init (Proxmox uses the VM name)
  networking.hostName = "";

  # cloud-init renders network config for systemd-networkd
  networking.useNetworkd = true;
  networking.useDHCP = false;

  services.cloud-init = {
    enable = true;
    network.enable = true;
    settings = {
      datasource_list = [ "NoCloud" "ConfigDrive" ];
      # Replaces the module's mkDefault system_info, so distro and renderers are repeated.
      system_info = {
        distro = "nixos";
        network.renderers = [ "networkd" ];
        # Proxmox `ciuser` overrides the name; the rest applies to that user.
        default_user = {
          name = "nixos";
          groups = [ "wheel" "docker" ];
          shell = "/run/current-system/sw/bin/bash";
          lock_passwd = true;
        };
      };
    };
  };

  # cloud-init creates the user once, on first boot of this image. Pre-create the
  # docker group with the gid virtualisation.docker uses, so a derived config that
  # enables Docker later finds the user already in the group.
  users.groups.docker.gid = lib.mkDefault config.ids.gids.docker;
}
