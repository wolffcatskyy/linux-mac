import importlib.machinery
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

loader = importlib.machinery.SourceFileLoader('smcfan', str(Path(__file__).parents[1] / 'smcfan-ce'))
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
loader.exec_module(module)


class FanTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        model = self.root / 'class/dmi/id/product_name'
        model.parent.mkdir(parents=True)
        model.write_text('MacPro6,1\n')
        self.path = self.root / 'devices/platform/applesmc.768'
        self.path.mkdir(parents=True)
        for key, value in dict(input=2100, output=790, min=790, max=2111, manual=0).items():
            (self.path / ('fan1_' + key)).write_text(str(value))
        self.fan = module.Fan(self.root)

    def test_maximum_and_release(self):
        self.fan.maximum()
        self.assertEqual(self.fan.read('output'), 2111)
        self.assertEqual(self.fan.read('manual'), 1)
        self.fan.automatic()
        self.assertEqual(self.fan.read('manual'), 0)

    def test_firmware_maximum_is_reread(self):
        self.fan.maximum()
        (self.path / 'fan1_max').write_text('2200')
        self.fan.maximum()
        self.assertEqual(self.fan.read('output'), 2200)

    def test_invalid_maximum_never_writes(self):
        for value in ('0', '700', '10001', 'broken'):
            with self.subTest(value=value):
                (self.path / 'fan1_max').write_text(value)
                with self.assertRaises(ValueError):
                    self.fan.maximum()
                self.assertEqual(self.fan.read('output'), 790)
                self.assertEqual(self.fan.read('manual'), 0)

    def test_wrong_model(self):
        (self.root / 'class/dmi/id/product_name').write_text('MacPro7,1')
        with self.assertRaises(ValueError):
            module.Fan(self.root)

    def test_multiple_controllers(self):
        other = self.path.parent / 'applesmc.999'
        other.mkdir()
        (other / 'fan1_max').write_text('2111')
        with self.assertRaises(ValueError):
            module.Fan(self.root)

    def test_second_fan(self):
        (self.path / 'fan2_input').write_text('2000')
        with self.assertRaises(ValueError):
            module.Fan(self.root)

    def test_ignored_write_is_detected(self):
        with patch.object(self.fan, 'write'):
            with self.assertRaises(OSError):
                self.fan.maximum()

    def test_missing_maximum_refuses(self):
        (self.path / 'fan1_max').unlink()
        with self.assertRaises(ValueError):
            module.Fan(self.root)

    def test_daemon_restores_auto_after_write_failure(self):
        with patch.object(module, 'Fan', return_value=self.fan), \
             patch('sys.argv', ['smcfan-ce', 'daemon']), \
             patch.object(self.fan, 'maximum', side_effect=OSError('device lost')), \
             patch.object(self.fan, 'automatic') as restore:
            with self.assertRaises(OSError):
                module.main()
            restore.assert_called_once()
