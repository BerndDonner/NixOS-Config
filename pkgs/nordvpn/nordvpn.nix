{ lib
, autoPatchelfHook
, buildFHSEnvChroot
, dpkg
, fetchurl
, stdenvNoCC
, sysctl
, iptables
, iproute2
, procps
, cacert
, libnl
, libcap_ng
, sqlite
, libxml2
, libidn2
, zlib
, wireguard-tools
, nftables
, libxslt
, systemd
, gcc-unwrapped
, ...
}:

let
  pname = "nordvpn";
  version = "6.0.1";

  nordVPNBase = stdenvNoCC.mkDerivation {
    inherit pname version;

    src = fetchurl {
      url = "https://repo.nordvpn.com/deb/nordvpn/debian/pool/main/n/nordvpn/nordvpn_${version}_amd64.deb";
      hash = "sha256-SYQ+zPNHfLapX9qXMYNcIa+Ittel0EkvuYF31vsDp3k=";
    };

    # Runtime dependencies of the unpacked binaries
    buildInputs = [
      libxml2
      zlib
      libidn2
      libnl
      sqlite
      libcap_ng
      gcc-unwrapped.lib
    ];

    # Tools needed only at build/unpack time
    nativeBuildInputs = [
      dpkg
      autoPatchelfHook
    ];

    # Explicit search directory for the bundled NordVPN shared libraries.
    preFixup = ''
      addAutoPatchelfSearchPath "$out/lib/nordvpn"
    '';

    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck
      export HOME="$TMPDIR/nordvpn-install-check"
      mkdir -p "$HOME"
      "$out/bin/nordvpn" --version | grep -F '6.0.1'
      test -x "$out/sbin/nordvpnd"
      test -x "$out/lib/nordvpn/norduserd"
      test -x "$out/lib/nordvpn/nordfileshare"
      test -s "$out/var/lib/nordvpn/data/ovpn_template.xslt"
      runHook postInstallCheck
    '';

    dontConfigure = true;
    dontBuild = true;

    unpackPhase = ''
      runHook preUnpack
      dpkg --extract "$src" .
      runHook postUnpack
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p "$out"
      mv usr/* "$out"/
      mv var/ "$out"/
      mv etc/ "$out"/
      runHook postInstall
    '';
  };

  nordVPNfhs = buildFHSEnvChroot {
    name = "nordvpnd";
    runScript = "${nordVPNBase}/sbin/nordvpnd";

    # Additional runtime deps in the FHS env
    targetPkgs = pkgs: [
      sqlite
      nordVPNBase
      sysctl
      iptables
      iproute2
      procps
      cacert
      libnl
      libcap_ng
      libxml2
      libidn2
      zlib
      wireguard-tools
      nftables
      libxslt # xsltproc is used to construct OpenVPN configurations in 6.x.
      systemd # resolvectl/systemctl used by the daemon on systemd hosts.
    ];
  };
in
stdenvNoCC.mkDerivation {
  inherit pname version;

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/bin" "$out/share"

    ln -s ${nordVPNBase}/bin/nordvpn "$out/bin/nordvpn"
    ln -s ${nordVPNfhs}/bin/nordvpnd "$out/bin/nordvpnd"

    ln -s ${nordVPNBase}/share/* "$out/share/"
    ln -s ${nordVPNBase}/var "$out/"

    runHook postInstall
  '';

  meta = with lib; {
    description = "CLI client for NordVPN";
    homepage = "https://www.nordvpn.com";
    # The distributed .deb declares License: Proprietary and bundles libraries;
    # this is not the GPL-only source build of the public client repository.
    license = licenses.unfreeRedistributable;
    mainProgram = "nordvpn";
    platforms = [ "x86_64-linux" ];
  };
}
