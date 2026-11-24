# web_demo_nerves

Minimal Nerves firmware for the `jslinux` target: Nerves running on a
RISC-V machine emulated by TinyEMU, compiled to WebAssembly, in a browser.

Sibling checkouts this expects:

* `../nerves_system_jslinux` - the Nerves system (path dependency)
* `../jsnerves` - the browser shell (TinyEMU wasm, terminal, loader)
* `../tinyemu` - the emulator source, only needed to rebuild the wasm

## Build and run

Host Erlang/Elixir are pinned in `mise.toml` (run through `mise exec --` or
activate mise). On Ubuntu 26.04 only, Buildroot 2026.08 refuses the uutils
`install` it ships, so put GNU coreutils first on PATH when the system has to
be built (24.04 and earlier need nothing):

```sh
mkdir -p ~/.gnu-coreutils-bin
for f in /usr/bin/gnu*; do ln -sf $f ~/.gnu-coreutils-bin/$(basename ${f#/usr/bin/gnu}); done
export PATH=~/.gnu-coreutils-bin:$PATH
```

```sh
export MIX_TARGET=jslinux
mix deps.get
mix firmware
cd ../jsnerves
./extract_firmware.sh ../web-demo-nerves/_build/jslinux_dev/nerves/images/web_demo_nerves.fw \
  ../nerves_system_jslinux/.nerves/artifacts/nerves_system_jslinux-portable-*/images
python3 -m http.server 8000   # then open http://localhost:8000/index.html
```

The `.fw` is a normal Nerves firmware file: `fwup -a -d disk.img -i ... -t complete`
writes an MBR, the U-Boot environment, A/B kernel slots, A/B rootfs partitions
and an application partition, and `-t upgrade` updates the inactive slot. In
the browser, OpenSBI and U-Boot boot the active slot from that disk image.
What the guest writes to the disk is kept in the browser's IndexedDB, so the
application partition and the firmware state survive a reload
(`index.html?reset=1` starts over), and a reboot resets the emulated machine
in place, so an upgrade applied inside the VM boots on the next reboot.

`sample/` is an untouched `mix nerves.new` output kept for reference.
