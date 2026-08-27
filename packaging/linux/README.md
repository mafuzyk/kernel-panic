# KERNEL PANIC — portable Linux x86_64

The portable release contains these two files in one directory:

```text
kernel-panic-linux-x86_64/
├── kernel-panic
└── kernel-panic.pck
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
