# TP-Link VX830v - xDSL board (EcoNet EN751627) dumping ground

## rootfs.patch.xz

A git binary patch against the extracted vendor squashfs containing:
- A busybox replacement
- startup script `rcS` modifications
  - add address `192.168.1.1/30` to `eth0.1` so it's reachable
    - configure `lan0` on the arm side as `192.168.1.2/30`
  - start `telnetd` for remote login
  - start `tftpd` in `/tmp/tftp` for remote file transfers
- `ucode` interpreter, selected modules and its dependencies

To apply:
- `cd` into the vanilla extracted vendor squashfs directory
- run `xzcat /somedir/rootfs.patch.xz | git apply -p2`

See also https://github.com/dhewg/linux-stable/tree/vx830v_xdsl?tab=readme-ov-file#readme-ov-file

## common.uc

A WIP framework for a potential replacement for the vendor `remote_board` - for *both sides*.

Written in `ucode`, implementing the vendor 0x88b5 protocol.

### client.uc

Uses `common.uc` to provide a client for the arm64 side.

It can talk to an unmodified vendor firmware on the econet side.

WIP, but it's able to establish a connection. Tested on VDSL.

### server.uc

Uses `common.uc` to provide a server for the econet side.

It only works when booting from a patched initramfs as described above.

It can run next to the vendor `remote_board` daemon. Currently it logs incoming client commands and provides one additional opcode for testing purposes:
- `32`, get server side metrics

Example:
- econet side
  ```
  $ ./server.uc
  xdsl server started on interface eth0.1.500, mac xxxxxxxxxxxx)
  server metrics = {
          "hardware_version": "T14.F7_0.0",
          "firmware_version": "5.12.30.0_A_A60901"
  }
  ptm_link_del: vlan=2000 delete=true
  atm_link_del: vlan=2000 delete=true
  ptm_link_add: enable=true vid=7 priority=0 vlan=2000
  ```

- arm64 side
  ```
  $ ./client.uc

  xdsl client started on interface lan0.500, mac xxxxxxxxxxxx)
  server metrics = {
    "hardware_version": "T14.F7_0.0",
    "firmware_version": "5.12.30.0_A_A60901"
  }
  link state change: (null) -> Silent
  link state change: Silent -> Training
  link state change: Training -> Showtime with TC-Layer sync
  modulation is G.993.2 (VDSL2), creating remote ptm link
  remote ptm link established, creating local vlan
  creating vlan 2000 on interface lan0
  ```

  ```
  $ ubus call xdsl metrics
  {
      "chipset": "EcoNet EN75xx",
      "hardware_version": "T14.F7_0.0",
      "firmware_version": "5.12.30.0_B_A60901",
      "up": true,
      "state_num": 7,
      "state": "Showtime with TC-Layer sync",
      "standard": "G.993.2",
      "profile": "17b",
      "mode": "G.993.2 (VDSL2, Profile 17b)",
      "annex": "A",
      "uptime": 166,
      "downstream": {
          "data_rate": 109998000,
          "attndr": 142611000,
          "snr": 12.199999999999999,
          "satn": 6.5999999999999996,
          "actatp": 11
      },
      "upstream": {
          "data_rate": 36998000,
          "attndr": 48614000,
          "snr": 13,
          "satn": 0,
          "actatp": 429496728.89999998
      }
  }
  ```

WIP, expect bugs.
