# web_demo_nerves

Nerves firmware for the `jslinux` target: Nerves running on a RISC-V machine
emulated by TinyEMU, compiled to WebAssembly, in a browser.

It is a `mix nerves.new` project (nerves_bootstrap 1.17.4) with these changes
for the target:

* `jslinux` is the only target, and its system is a path dependency built
  from source.
* No networking: the browser gives the machine no network, so instead of
  `nerves_pack` it only has the part of it that is not networking,
  `nerves_motd`. No vintage_net, mdns_lite, nerves_ssh or nerves_time, and
  none of their configuration (SSH keys from `~/.ssh` included).
* `config :nerves_runtime, fwup_timeout: 4_000`: the firmware status read
  when nerves_runtime's KV store first loads gets 4 s instead of 1 s, since
  fwup starts slowly on the emulated CPU while the system boots. Only
  nerves_runtime's main branch passes that setting on (commit b53eaa9;
  0.13.13 is the latest release), so nerves_runtime comes from git. Back to
  Hex once a release has it.

* `WebDemoNerves.Board`: the board's LEDs, buttons and sensors, with
  Circuits.GPIO and Circuits.I2C. The emulated machine has a virtio GPIO
  controller and I2C adapter whose other side is the page (see Board in
  `../jsnerves/README.md`): it lights `LED_SLOT_A` or `LED_SLOT_B` for the
  running slot and `LED_READY` once the system is up, logs presses of
  `BUTTON_1` to `BUTTON_3`, and `WebDemoNerves.Board.fps()` reads the page's
  frame rate from the FPS sensor at I2C address `0x10`.

Everything else is the template: Toolshed and the MOTD in
`rootfs_overlay/etc/iex.exs`, RingLogger, and the Nerves.Runtime startup
guard, which validates new firmware once all applications have started.

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
  ../nerves_system_jslinux/.nerves/artifacts/nerves_system_jslinux-portable-$(cat ../nerves_system_jslinux/VERSION)/images
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

