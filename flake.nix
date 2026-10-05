{
  description = "Generic NixOS image for Proxmox: disko layout, identity from cloud-init";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko, ... }: {
    # Everything a derived config needs to stay compatible with the image:
    # same disk layout, bootloader, cloud-init and base settings.
    nixosModules.default = { modulesPath, ... }: {
      imports = [
        (modulesPath + "/profiles/qemu-guest.nix")
        disko.nixosModules.disko
        ./disko.nix
        ./modules/base.nix
        ./modules/cloud-init.nix
      ];
    };

    nixosConfigurations.default = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        self.nixosModules.default
        ./hosts/default.nix
      ];
    };

    # nix build .#image  ->  result/main.raw
    packages.x86_64-linux.image =
      self.nixosConfigurations.default.config.system.build.diskoImages;

    checks.x86_64-linux.toplevel =
      self.nixosConfigurations.default.config.system.build.toplevel;
  };
}
