# Hoppscotch Flatpak

This folder contains a Flatpak manifest to package the latest prebuilt [Hoppscotch](https://github.com/hoppscotch/hoppscotch) binary
from the official [GitHub releases](https://github.com/hoppscotch/releases/releases).

## Build and Install

You can build and install the Flatpak locally:

```bash
flatpak install org.gnome.Platform/x86_64/50
flatpak-builder --user --install --force-clean build-dir com.hoppscotch.Hoppscotch.yml
flatpak run com.hoppscotch.Hoppscotch
```

## Install from repo
Alternatively, you can install Hoppscotch directly from the Flatpak repository:

```bash
flatpak remote-add --user --no-gpg-verify hoppscotch-repo https://shyvortex.github.io/hoppscotch-flatpak/
flatpak install org.gnome.Platform/x86_64/50
flatpak install hoppscotch-repo com.hoppscotch.Hoppscotch
flatpak run com.hoppscotch.Hoppscotch
```
