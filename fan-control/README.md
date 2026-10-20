# smcFanControl CE for Linux

This repository includes an independent Linux backend for the smcFanControl CE fixed-maximum policy. It uses the kernel's `applesmc` sysfs interface; it does not run the macOS app or include commercial code. Only physical `MacPro6,1` is accepted. One chassis fan is expected.

The daemon reads `fan1_max`, writes it to `fan1_output`, enables manual mode and verifies both settings. It repeats every two seconds, including after resume. No hard-coded RPM fallback is used. A tachometer reading can fluctuate around the target. SIGTERM, SIGINT and operation failures attempt to restore automatic control. SIGKILL, a kernel failure or power loss cannot run cleanup; systemd's stop hook also attempts release while the OS is operating. Restart-on-failure retries the controller.

## Install and migrate

The Arch kernel package includes the executable and unit. For an existing installation or other systemd distributions, run from the repository root:

```bash
sudo bash fan-control/install.sh
```

Installation alone does not start the controller. Check for other fan services first:

```bash
systemctl status macfanctld mbpfan fancontrol macpro-fan-full --no-pager
/usr/bin/python3 /usr/bin/smcfan-ce status
```

Disable whichever competing controller you actually use, then enable ours. The unit conflicts with the common competing services so they cannot run together through systemd. Disable their boot enablement too, to avoid competing boot jobs. For example, if using `macfanctld`:

```bash
sudo systemctl disable --now macfanctld.service
sudo systemctl enable --now smcfan-ce.service
/usr/bin/python3 /usr/bin/smcfan-ce status
```

The expected status has `manual: 1` and `output` equal to `max`. Verify `input` approaches the target. No package is automatically removed. Kernel installation prints the activation command; image overlay staging enables the service inside the target image, never on the build host. No kernel or ISO rebuild has been validated for this change.

## Return to firmware control

```bash
sudo systemctl disable --now smcfan-ce.service
sudo /usr/bin/python3 /usr/bin/smcfan-ce auto
```

Re-enable your previous controller only if desired. Source installation can be removed by deleting `/usr/bin/smcfan-ce` and `/usr/lib/systemd/system/smcfan-ce.service` after stopping it, then running `sudo systemctl daemon-reload`.

## Validation

```bash
python3 -m unittest discover -s fan-control/tests -v
systemd-analyze verify fan-control/smcfan-ce.service
```

The fixture tests exercise wrong-model refusal, invalid limits, controller count, readback failure and firmware release. They do not prove physical fan motion or image boot behavior. Read-only physical Linux checks are recorded separately; replacing a live controller requires an explicit migration.

The old `configs/MacPro6,1/fan/macfanctld.conf` is retained only as legacy reference. It is not installed or used by smcFanControl CE. This initial backend provides fixed maximum speed, not the macOS app's full interface or temperature curves.
