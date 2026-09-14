{ config, ... }:

let
  webDomain = config.services.forgejo.settings.server.DOMAIN;
  httpAddr = config.services.forgejo.settings.server.HTTP_ADDR;
  httpPort = toString config.services.forgejo.settings.server.HTTP_PORT;
in
{
  # git.the-darkroom.org is DNS-only at Cloudflare, so Caddy talks directly to
  # the ACME CA and terminates TLS on cloud. WebSockets are handled by Caddy's
  # reverse_proxy automatically.
  services.caddy = {
    enable = true;

    virtualHosts.${webDomain}.extraConfig = ''
      encode zstd gzip
      reverse_proxy ${httpAddr}:${httpPort}
    '';
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
