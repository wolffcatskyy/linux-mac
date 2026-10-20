# smcFanControl CE for Linux

This repository includes an independent Linux backend for the smcFanControl CE fixed-maximum policy. It uses the kernel's `applesmc` sysfs interface; it does not run the macOS app or include commercial code. Only physical `MacPro6,1` is accepted. One chassis fan is expected.

The daemon reads `fan1_max`, writes it to `fan1_output`, enables manual mode and verifies both settings. It repeats every two seconds, including after resume. No hard-coded RPM fallback is used. A tachometer reading can fluctuate around the target. SIGTERM, SIGINT and operation failures attempt to restore automatic control. SIGKILL, a kernel failure or power loss cannot run cleanup; systemd's stop hook also attempts release while the OS is operating. Restart-on-failure retries the controller.

## Install and migrate

The Arch kernel package includes the executable and unit. For an existing installation or other systemd distributions, run from the repository root:

```bash
sudo bash fan-control/install.sh
```

On a live physical MacPro6,1 with systemd, both the source installer and kernel package install/upgrade start the controller immediately and enable it for boot. Existing macfanctld, mbpfan, fancontrol and macpro-fan-full units have their boot enablement removed; the new service stops their running instances through systemd conflicts. Packages are retained for rollback.

In a chroot, container or offline target, installation only enables the target service for boot. Image staging with DESTDIR only writes the target overlay; it does not call host systemctl or access fan controls. The live ISO starts the enabled service at its own multi-user boot, so it controls the fan while the installer is running, before any desktop login. An installed target also starts it at boot.

Check the running controller with:

```bash
systemctl status smcfan-ce.service --no-pager
/usr/bin/python3 /usr/bin/smcfan-ce status
```

The expected status has `manual: 1` and `output` equal to `max`. Verify `input` approaches the target. No package is automatically removed. Image overlay staging enables the service inside the target image, never on the build host. No kernel or ISO rebuild has been validated for this change.

## Return to firmware control

```bash
sudo systemctl disable --now smcfan-ce.service
sudo /usr/bin/python3 /usr/bin/smcfan-ce auto
```

Re-enable your previous controller only if desired. Source installation can be removed by deleting `/usr/bin/smcfan-ce` and `/usr/lib/systemd/system/smcfan-ce.service`, plus `/usr/lib/smcfan-ce/activate.sh` after stopping it, then running `sudo systemctl daemon-reload`.

## Validation

```bash
python3 -m unittest discover -s fan-control/tests -v
systemd-analyze verify fan-control/smcfan-ce.service
```

The fixture tests exercise wrong-model refusal, invalid limits, controller count, readback failure and firmware release. They do not prove physical fan motion or image boot behavior. Read-only physical Linux checks are recorded separately; replacing a live controller requires an explicit migration.

The old `configs/MacPro6,1/fan/macfanctld.conf` is retained only as legacy reference. It is not installed or used by smcFanControl CE. This initial backend provides fixed maximum speed, not the macOS app's full interface or temperature curves.
