# tools/vm - build the iOS root image without root on the host

`tools/mkiosroot.sh` needs root for exactly one thing: writing the iOS file
tree into the HFS+ volume.  `mount -t hfsplus` needs root, and every
writable userspace HFS+ driver (hfsfuse, hfsplus-fuse, ...) is read-only, so
there is no way around it on the host.

The trick is to move that one privileged step into a qemu guest, where the
guest's root does the work:

```
host (unprivileged)                 qemu guest (root)
-----------------------------------  ------------------------------------
apfs-fuse mounts the IPSW images     mounts the HFS+ image read-write
tar --numeric-owner archives        extracts the archives as root, so the
                                    APFS owners (0:80, 501:501, 272:272)
                                    survive into the volume
img2simg converts to a sparse image
```

## Files

| file                | role                                                  |
|---------------------|-------------------------------------------------------|
| `fetch-guest.sh`    | download the Alpine netboot kernel/initramfs/modloop  |
| `build-in-vm.sh`    | boot the guest and drive it over the serial console   |
| `vmrun.py`          | expect-like serial console driver                     |
| `build-in-guest.sh` | the build itself, runs as root inside the guest       |

## Why the guest is Alpine "lts"

`CONFIG_HFSPLUS_FS=m` only exists in the `lts` flavour.  The `virt` flavour
has no HFS+ support at all, so the guest could not mount the volume it has to
build.  The guest boots the netboot kernel with the modloop carrying the
modules.

## Why the archives are virtio disks and not 9p

The guest's `virtio-pci` does not bind the modern 0x1111 9p device: the
`virtio_pci_modern_dev` module loads, but `virtio-9p-pci` never appears and
a manual bind to `/sys/bus/pci/drivers/virtio-pci/bind` fails.  So the
archives are attached as plain virtio block devices and unpacked with
`tar xpf /dev/vdb`.

## Memory

The guest needs `MEM=8192`.  With 4 GB the page allocator hits a soft lockup
during boot (`__alloc_frozen_pages_noprof`).

## Slow boots

The modloop is 290 MB and is downloaded on every boot, which makes each boot
take a few minutes.  Serving it from the host over the slirp gateway
(`10.0.2.2`) makes the boot much faster:

```sh
cd "$GUESTDIR" && python3 -m http.server 8000 &
MODLOOP_URL=http://10.0.2.2:8000/modloop-lts tools/build-iosroot-vm.sh ...
```

## Known quirk: two Thai file names

`System/Library/PrivateFrameworks/WorkflowKit.framework/*/th.lproj/DefaultShortcuts/`
holds two `.shortcut` files whose names Linux' `hfsplus` driver decomposes
differently from Apple's tables, so `find` reports them as missing.  The files
are present in the volume; only the name lookup differs.  `fsck.hfsplus -f -y`
rewrites them, the same way `tools/mkiosroot.sh` does.
