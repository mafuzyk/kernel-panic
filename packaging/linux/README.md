# KERNEL PANIC — portable Linux x86_64

The portable release is a single file: the project data is embedded in the
executable (preset `Linux x86_64` sets `binary_format/embed_pck=true`).

```text
kernel-panic-linux-x86_64/
└── kernel-panic
```

Build it from the repository root with:

```sh
mkdir -p build/linux-x86_64
godot --headless --path . --export-release "Linux x86_64" build/linux-x86_64/kernel-panic
```

Smoke-test the exported game:

```sh
./build/linux-x86_64/kernel-panic --headless -- --autotest
```

The later `kernel-panic-bin` package can install this directory under
`/opt/kernel-panic` and provide a launcher without changing the game export.
