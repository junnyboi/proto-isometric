# Proto Isometric

A Godot 4.7.1 isometric prototype scaffold. The launch scene is a keyboard- and pointer-accessible tactical title screen that transitions into a procedural isometric staging field.

## Toolchain

Run the project-bundled `bootstrap-godot-4.7.1.sh` recovery script from the Manus project files with `MGS_INSTALL_WEB_TEMPLATE=1`. The expected regular engine binary SHA-256 is `32f8d7596c4b41185512b1c49d69f2da3be018fd784a53e349fa92a98a97bcde`; the no-threads web template SHA-256 is `b7b7d7da29fc6cc2f4934fdd26cc571a40e7af57f716ea3eb7e18da720dae28a`.

## Run

```bash
$HOME/bin/godot --path .
```

## Verify

```bash
./verify.sh
./verify.sh --full
```

The full gate performs lint, nonzero GUT tests, fresh import and boot, seeded headless and Xvfb scenarios with mandatory completion sentinels, fresh 1280×720 PNG validation, and a no-threads Web export to `/home/ubuntu/proto-isometric-build/web`.

## Controls

Press **Enter** or activate **BEGIN** with the pointer to open the staging field.
