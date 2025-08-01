nvidia_x11: sha256:

{
  stdenv,
  lib,
  fetchFromGitHub,
  fetchpatch,
  pkg-config,
  m4,
  jansson,
  gtk2,
  dbus,
  vulkan-headers,
  gtk3,
  libXv,
  libXrandr,
  libXext,
  libXxf86vm,
  libvdpau,
  librsvg,
  libglvnd,
  wrapGAppsHook3,
  addDriverRunpath,
  withGtk2 ? false,
  withGtk3 ? true,
}:

let
  src = fetchFromGitHub {
    owner = "NVIDIA";
    repo = "nvidia-settings";
    rev = nvidia_x11.settingsVersion;
    inherit sha256;
  };

  meta = with lib; {
    homepage = "https://www.nvidia.com/object/unix.html";
    platforms = nvidia_x11.meta.platforms;
    maintainers = with maintainers; [
      abbradar
      aidalgol
    ];
  };

  libXNVCtrl = stdenv.mkDerivation {
    pname = "libXNVCtrl";
    version = nvidia_x11.settingsVersion;
    inherit src;

    buildInputs = [
      libXrandr
      libXext
    ];

    preBuild = ''
      cd src/libXNVCtrl
    '';

    makeFlags = [
      "OUTPUTDIR=." # src/libXNVCtrl
      "libXNVCtrl.a"
      "libXNVCtrl.so"
    ];

    patches = [
      # Patch the Makefile to also produce a shared library.
      (
        if lib.versionOlder nvidia_x11.settingsVersion "400" then
          ./libxnvctrl-build-shared-3xx.patch
        else
          ./libxnvctrl-build-shared.patch
      )
    ];

    installPhase = ''
      mkdir -p $out/lib
      mkdir -p $out/include/NVCtrl

      cp libXNVCtrl.a $out/lib
      cp NVCtrl.h     $out/include/NVCtrl
      cp NVCtrlLib.h  $out/include/NVCtrl
      cp -P libXNVCtrl.so* $out/lib
    '';

    meta = meta // {
      description = "NVIDIA NV-CONTROL X extension";
      # https://github.com/NVIDIA/nvidia-settings/commit/edcf9edad9f52f9b10e63d4480bbe88b22dde884
      license = lib.licenses.mit;
    };
  };

  runtimeDependencies = [
    libglvnd
    libXrandr
    libXv
  ];

  runtimeLibraryPath = lib.makeLibraryPath runtimeDependencies;

in

stdenv.mkDerivation {
  pname = "nvidia-settings";
  version = nvidia_x11.settingsVersion;

  inherit src;

  patches =
    lib.optional (lib.versionOlder nvidia_x11.settingsVersion "440") (fetchpatch {
      # fixes "multiple definition of `VDPAUDeviceFunctions'" linking errors
      url = "https://github.com/NVIDIA/nvidia-settings/commit/a7c1f5fce6303a643fadff7d85d59934bd0cf6b6.patch";
      hash = "sha256-ZwF3dRTYt/hO8ELg9weoz1U/XcU93qiJL2d1aq1Jlak=";
    })
    ++
      lib.optional
        (
          (lib.versionAtLeast nvidia_x11.settingsVersion "515.43.04")
          && (lib.versionOlder nvidia_x11.settingsVersion "545.29")
        )
        (fetchpatch {
          # fix wayland support for compositors that use wl_output version 4
          url = "https://github.com/NVIDIA/nvidia-settings/pull/99/commits/2e0575197e2b3247deafd2a48f45afc038939a06.patch";
          hash = "sha256-wKuO5CUTUuwYvsP46Pz+6fI0yxLNpZv8qlbL0TFkEFE=";
        });

  postPatch = lib.optionalString nvidia_x11.useProfiles ''
    sed -i 's,/usr/share/nvidia/,${nvidia_x11.bin}/share/nvidia/,g' src/gtk+-2.x/ctkappprofile.c
  '';

  enableParallelBuilding = true;
  makeFlags = [ "NV_USE_BUNDLED_LIBJANSSON=0" ];

  preBuild = ''
    if [ -e src/libXNVCtrl/libXNVCtrl.a ]; then
      ( cd src/libXNVCtrl
        make $makeFlags
      )
    fi
  '';

  nativeBuildInputs = [
    pkg-config
    m4
    addDriverRunpath
  ]
  ++ lib.optionals withGtk3 [ wrapGAppsHook3 ];

  buildInputs = [
    jansson
    libXv
    libXrandr
    libXext
    libXxf86vm
    libvdpau
    nvidia_x11
    dbus
    vulkan-headers
  ]
  ++ lib.optionals (withGtk2 || lib.versionOlder nvidia_x11.settingsVersion "525.53") [ gtk2 ]
  ++ lib.optionals withGtk3 [
    gtk3
    librsvg
  ];

  installFlags = [ "PREFIX=$(out)" ];

  postInstall =
    lib.optionalString (!withGtk2) ''
      rm -f $out/lib/libnvidia-gtk2.so.*
    ''
    + lib.optionalString (!withGtk3) ''
      rm -f $out/lib/libnvidia-gtk3.so.*
    ''
    + ''
      # Install the desktop file and icon.
      # The template has substitution variables intended to be replaced resulting
      # in absolute paths. Because absolute paths break after the desktop file is
      # copied by a desktop environment, make Exec and Icon be just a name.
      sed -i doc/nvidia-settings.desktop \
        -e "s|^Exec=.*$|Exec=nvidia-settings|" \
        -e "s|^Icon=.*$|Icon=nvidia-settings|" \
        -e "s|__NVIDIA_SETTINGS_DESKTOP_CATEGORIES__|Settings|g"
      install doc/nvidia-settings.desktop -D -t $out/share/applications/
      install doc/nvidia-settings.png -D -t $out/share/icons/hicolor/128x128/apps/
    '';

  binaryName = if withGtk3 then ".nvidia-settings-wrapped" else "nvidia-settings";
  postFixup = ''
    patchelf --set-rpath "$(patchelf --print-rpath $out/bin/$binaryName):$out/lib:${runtimeLibraryPath}" \
      $out/bin/$binaryName

    addDriverRunpath $out/bin/$binaryName
  '';

  passthru = {
    inherit libXNVCtrl;
  };

  meta = meta // {
    description = "Settings application for NVIDIA graphics cards";
    # nvml.h is licensed as part of the cuda developer license.
    license = lib.licenses.unfreeRedistributable;
    mainProgram = "nvidia-settings";
  };
}
