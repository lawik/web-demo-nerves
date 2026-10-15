# web_demo_nerves

Minimal Nerves firmware for the `jslinux` target: Nerves running on a
RISC-V machine emulated by TinyEMU, compiled to WebAssembly, in a browser.

Sibling checkouts this expects:

* `../nerves_system_jslinux` - the Nerves system (path dependency)
* `../jsnerves` - the browser shell (TinyEMU wasm, terminal, loader)
* `../tinyemu` - the emulator source, only needed to rebuild the wasm

## Build and run

```sh
export MIX_TARGET=jslinux
mix deps.get
mix firmware
cd ../jsnerves
./extract_firmware.sh ../web-demo-nerves/_build/jslinux_dev/nerves/images/web_demo_nerves.fw \
  ../nerves_system_jslinux/.nerves/artifacts/nerves_system_jslinux-portable-*
./start.sh   # then open http://localhost:8000/index.html
```

`sample/` is an untouched `mix nerves.new` output kept for reference.
