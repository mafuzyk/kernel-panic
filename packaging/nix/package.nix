{ lib
, stdenv
, godot_4_7
, godot_4_7-export-templates-bin
, autoPatchelfHook
, alsa-lib
, dbus
, fontconfig
, libdecor
, libGL
, libpulseaudio
, libxkbcommon
, systemdLibs
, wayland
, xorg
, version ? "3.1.0"
, src ? ../..
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "kernel-panic";
  inherit version src;

  nativeBuildInputs = [ godot_4_7 autoPatchelfHook ];

  # Só a glibc é LINKADA. Todo o resto — X11, EGL, ALSA, PulseAudio, dbus,
  # fontconfig, libdecor, udev — o Godot abre com dlopen em tempo de execução,
  # onde o autoPatchelf não enxerga. `runtimeDependencies` é o que põe essas
  # bibliotecas no RPATH mesmo sem referência no ELF.
  runtimeDependencies = [
    alsa-lib
    dbus
    fontconfig
    libdecor
    libGL
    libpulseaudio
    libxkbcommon
    systemdLibs
    wayland
    xorg.libX11
    xorg.libXcursor
    xorg.libXext
    xorg.libXi
    xorg.libXinerama
    xorg.libXrandr
    xorg.libXrender
  ];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild

    # O Godot procura os templates no HOME. O sandbox do Nix não tem um, então
    # ele ganha um descartável apontando para o pacote de templates.
    export HOME=$(mktemp -d)
    mkdir -p "$HOME/.local/share/godot/export_templates"
    ln -s ${godot_4_7-export-templates-bin}/share/godot/export_templates/* \
      "$HOME/.local/share/godot/export_templates/"

    mkdir -p out
    # Uma passada de import antes: sem ela o primeiro export sai com recursos
    # ainda não importados e o pacote nasce sem parte dos assets.
    godot4 --headless --path . --import >/dev/null 2>&1 || true
    godot4 --headless --path . --export-release "Linux x86_64" out/kernel-panic

    runHook postBuild
  '';


  installPhase = ''
    runHook preInstall

    install -Dm755 out/kernel-panic $out/bin/kernel-panic
    install -Dm644 packaging/void/kernel-panic.desktop \
      $out/share/applications/kernel-panic.desktop
    install -Dm644 assets/icons/launcher.png \
      $out/share/icons/hicolor/192x192/apps/kernel-panic.png
    install -Dm644 LICENSE $out/share/licenses/kernel-panic/LICENSE

    runHook postInstall
  '';

  # A suíte roda DEPOIS do fixup, contra o binário instalado.
  #
  # Em `checkPhase` ela falhava com "cannot execute: required file not found":
  # o `autoPatchelfHook` só corrige o interpretador dinâmico no `fixupPhase`, e
  # até lá o artefato ainda aponta para um /lib64 que não existe no Nix.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME=$(mktemp -d)
    $out/bin/kernel-panic --headless -- --autotest | tee autotest.log
    grep -q AUTOTEST_ALL_PASS autotest.log
    runHook postInstallCheck
  '';

  meta = {
    description = "Neon arena shooter about keeping one stubborn process alive";
    homepage = "https://github.com/mafuzyk/kernel-panic";
    license = lib.licenses.mit;
    mainProgram = "kernel-panic";
    platforms = [ "x86_64-linux" ];
  };
})
