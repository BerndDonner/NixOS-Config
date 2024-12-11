{
  lib,
  stdenv,
  fetchgit,
  gcc14Stdenv,
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
    rev = "39126a5f2eef07260a402304e355d915a957ae15";
    hash = "sha256-C8UuJ8fZzYTIIPBp3TG8NC/axawPokLzMSBgbNUVYZs=";
  };


  buildInputs = [
    qt6.full
    qt6.qtbase
    qt6.qtdoc
    qt6.qtsvg
    qt6.qtquick3d
    qt6.qtwebengine
    qt6.qtwayland
    qt6.qtserialport
    qt6.qtshadertools
    qt6.qt5compat
    qt6.qtdeclarative
    qt6.qtquicktimeline
    openssl
  ];

  nativeBuildInputs = [
    cmake
    gcc14Stdenv
    pkg-config
    qt6.qttools
    # qt6.qtdeclarative
    qt6.wrapQtAppsHook
  ];

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
    "-DQT_QML_PLUGINS_DIR=${qt6.qtdeclarative}/lib/qt-6/qml/QtQuick"
    "-DQT_INSTALL_PLUGINS_DIR=${qt6.qtdeclarative}/lib/qt-6/qml/QtQuick"
    # "--trace-expand"
    # "-DINSTALL_PLUGINSDIR=${qtPluginPrefix}"
    # "-DINSTALL_QMLDIR=${qtQmlPrefix}"
    # "-DCMAKE_INSTALL_PREFIX:PATH=$out"
  ];

  buildPhase = ''
    echo "CMake Command: cmake ${toString cmakeFlags} ."
    cmake ${toString cmakeFlags} .
    make
  '';
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

