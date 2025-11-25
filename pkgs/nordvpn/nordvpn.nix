{ lib
, autoPatchelfHook
, buildFHSEnvChroot
, dpkg
, fetchurl
, stdenv
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
, ...
}:

let
  pname = "nordvpn";
  version = "4.1.1";

  nordVPNBase = stdenv.mkDerivation {
    inherit pname version;

    src = fetchurl {
      url = "https://repo.nordvpn.com/deb/nordvpn/debian/pool/main/n/nordvpn/nordvpn_${version}_amd64.deb";
      hash = "sha256-JWgY0V2GbA9fJ01VhiGfUvVzau/FLOd/kDu2nQ3rMuY=";
    };

    # Runtime dependencies of the unpacked binaries
    buildInputs = [
      libxml2
      libidn2
      libnl
      sqlite
      libcap_ng
      stdenv.cc.cc.lib
    ];

    # Tools needed only at build/unpack time
    nativeBuildInputs = [
      dpkg
      autoPatchelfHook
    ];

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
    runScript = "nordvpnd";

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
    ];
  };
in
stdenv.mkDerivation {
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
    license = licenses.unfreeRedistributable;
    maintainers = with lib.maintainers; [ dr460nf1r3 ];
    platforms = [ "x86_64-linux" ];
  };
}
