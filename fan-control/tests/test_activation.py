from pathlib import Path
import os
import subprocess
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[1]


class ActivationTests(unittest.TestCase):
    def activation(self, live, fail=False):
        # Source only; substitute systemctl so tests cannot touch host services.
        script = r'''
source "$1"
live_status=$2
is_live_mac() { return "$live_status"; }
systemctl() {
    printf 'CALL %s\n' "$*"
    if [[ $1 == enable && ${FAIL_START:-0} == 1 && ${2:-} == --now ]]; then
        return 1
    fi
}
activate_main
'''
        env = dict(os.environ, FAIL_START='1' if fail else '0')
        return subprocess.run(['bash', '-c', script, '_', str(SOURCE / 'activate.sh'), '0' if live else '1'],
                              text=True, capture_output=True, env=env)

    def test_live_install_starts_now_and_disables_competitors(self):
        result = self.activation(True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('CALL enable --now smcfan-ce.service', result.stdout)
        self.assertIn('CALL is-active --quiet smcfan-ce.service', result.stdout)
        for unit in ('macfanctld', 'mbpfan', 'fancontrol', 'macpro-fan-full'):
            self.assertIn('CALL disable ' + unit + '.service', result.stdout)
        self.assertLess(result.stdout.index('CALL disable'), result.stdout.index('CALL enable --now'))

    def test_offline_install_only_enables(self):
        result = self.activation(False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('CALL enable smcfan-ce.service', result.stdout)
        self.assertNotIn('--now', result.stdout)
        self.assertNotIn('CALL disable', result.stdout)
        self.assertNotIn('daemon-reload', result.stdout)

    def test_start_failure_is_not_reported_as_success(self):
        result = self.activation(True, fail=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('started now', result.stdout)

    def test_image_staging_never_calls_systemctl(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            mockbin = root / 'bin'
            mockbin.mkdir()
            mock = mockbin / 'systemctl'
            mock.write_text('#!/bin/sh\necho "unexpected systemctl" >&2\nexit 99\n')
            mock.chmod(0o755)
            dest = root / 'image'
            env = dict(os.environ, DESTDIR=str(dest), PATH=str(mockbin) + ':' + os.environ['PATH'])
            result = subprocess.run(['bash', str(SOURCE / 'install.sh')], env=env, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue((dest / 'usr/bin/smcfan-ce').is_file())
            self.assertTrue((dest / 'usr/lib/smcfan-ce/activate.sh').is_file())
            link = dest / 'etc/systemd/system/multi-user.target.wants/smcfan-ce.service'
            self.assertTrue(link.is_symlink())
            self.assertEqual(os.readlink(link), '/usr/lib/systemd/system/smcfan-ce.service')
