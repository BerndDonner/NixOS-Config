{
  lib,
  stdenv,
  fetchgit,
  qt6,
  openssl,
  cmake,
  pkg-config,
} :

stdenv.mkDerivation {
  pname = "Serial-Studio";
  version = "3.0.6"; #TODO can we automatically set the version from github?

  meta = with lib; {
    description = "Serial Studio is a multi-platform, versatile data visualization tool designed for embedded engineers, students, hackers, and teachers.";
    homepage    = "https://github.com/BerndDonner/Serial-Studio";
    license     = licenses.mit;
    platforms   = platforms.linux;
    maintainers = [ ]; #TODO
  };

  src = fetchgit {
    url = "https://github.com/BerndDonner/Serial-Studio";
    branchName = "nixos";
    rev = "1bb9cd3d544eaf5ada8a8cb08a6e1308e839680f";
    hash = "sha256-hyYrJkbicsj3jaEytKH7sRIXNT5SxNb3UE75GSzGCBM=";
  };


  buildInputs = [
    qt6.qtbase
    qt6.qtsvg
    qt6.qtgraphs
    qt6.qtlocation
    qt6.qtconnectivity
    openssl
  ];

  nativeBuildInputs = [
    cmake
    pkg-config
    qt6.qttools
    qt6.wrapQtAppsHook
  ];

  preConfigure = ''
    export LC_ALL=C.UTF-8
    export QT_DEPLOY_USE_PATCHELF=ON
    # export RPATH_SET=patchelf
    # export NIXPKGS_QT6_QML_IMPORT_PATH=/nix/store/my7sl14chw7q6fy57acyikb8wk2sgbwq-qtgraphs-6.8.0/lib/qt-6/qml/QtGraphs
    # qtWrapperArgs+=(--prefix NIXPKGS_QT6_QML_IMPORT_PATH : "$qmlDir")
  '';
  
  # preInstall = ''
  #   echo "1 BERND QT_PLUGIN_PATH: $QT_PLUGIN_PATH"
  #   echo "1 BERND QML2_IMPORT_PATH: $QML2_IMPORT_PATH"

  #   defaultPreInstall
  # '';
  
  # installPhase = ''
  #   echo "2 BERND QT_PLUGIN_PATH: $QT_PLUGIN_PATH"
  #   echo "2 BERND QML2_IMPORT_PATH: $QML2_IMPORT_PATH"

  #   defaultInstallPhase
  # '';
  
  # postInstall = ''
  #   echo "3 BERND QT_PLUGIN_PATH: $QT_PLUGIN_PATH"
  #   echo "3 BERND QML2_IMPORT_PATH: $QML2_IMPORT_PATH"

  #   defaultPostInstall
  # '';
  

  # qtPluginPrefix = "lib/qt-6/plugins";
  # qtQmlPrefix = "lib/qt-6/qml";

    # postPatch = ''
  #   substituteInPlace CMakeLists.txt \
  #     --replace "/usr/share/pixmaps" "share/pixmaps"
  #           --replace 'CMAKE_INSTALL_PREFIX "/usr"' "CMAKE_INSTALL_PREFIX $out"
  #   substituteInPlace app/CMakeLists.txt \
  #     --replace 'DESTINATION usr/share' "DESTINATION share"
  # '';

  # postConfigure = ''
  #   substituteInPlace cmake_install.cmake \
  #     --replace "/var/empty" "/usr"
  # '';


  # qtWrapperArgs = [ ''--prefix PATH : /path/to/bin'' ];
  cmakeFlags = [
    "-DPRODUCTION_OPTIMIZATION=ON"
    "-DCMAKE_BUILD_TYPE=Release"
    "-DQT_DEPLOY_USE_PATCHELF=ON"
    # "-DQT_QML_PLUGINS_DIR=${qt6.qtdeclarative}/lib/qt-6/qml/QtQuick"
    # "-DQT_INSTALL_PLUGINS_DIR=${qt6.qtdeclarative}/lib/qt-6/qml/QtQuick"
    # "--trace-expand"
    # "-DINSTALL_PLUGINSDIR=${qtPluginPrefix}"
    # "-DINSTALL_QMLDIR=${qtQmlPrefix}"
    # "-DCMAKE_INSTALL_PREFIX:PATH=$out"
  ];

  # buildPhase = ''
  #   echo "CMake Command: cmake ${cmakeFlags[@]} ..."
  #   cmake "${cmakeFlags[@]}" .
  #   make
  # '';

  # The let .. in .. construct seems perfect for this function definition,
  # since I do not want the function definition to be visible to the outside
  # the function createWrapper is only an internal helper to prevent repetitive
  # code.
  #
  # all the wrapper does is calling context, mtxrun and luametatex with the
  # absolute path. Changing the filenames of theese binaries would break the code
  # by the way. The impementation of the only real binary luametatex does find
  # the fonts and other neccessary data when called via absolute path.
}

