{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/disk/by-id/virtio-32301b376481bfb9d8e0";

    content = {
      type = "gpt";

      partitions = {
        bios = {
          size = "1M";
          type = "EF02";
          priority = 1;
        };

        swap = {
          size = "4G";
          priority = 2;

          content = {
            type = "swap";
          };
        };

        root = {
          size = "100%";
          priority = 3;

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
