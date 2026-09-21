#!/usr/bin/env python3
"""Exercise updater failure handling with local fixtures, without installing anything."""

import os
from pathlib import Path
import subprocess
import tempfile
import tomllib
import unittest


ROOT = Path(__file__).resolve().parents[1]


class UpdateWorkflows(unittest.TestCase):
    def test_homebrew_does_not_upgrade_after_metadata_refresh_fails(self):
        task = tomllib.loads((ROOT / "mise.toml").read_text())["tasks"]["homebrew-upgrade"]["run"]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            log = root / "calls"
            brew = root / "brew"
            brew.write_text('#!/bin/bash\nprintf "%s\\n" "$*" >> "$TEST_BREW_LOG"\nexit 23\n')
            brew.chmod(0o755)
            result = subprocess.run(
                ["bash", "-e", "-c", task],
                env={**os.environ, "PATH": f"{root}:{os.environ['PATH']}",
                     "TEST_BREW_LOG": str(log)},
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 23)
            self.assertEqual(log.read_text().splitlines(), ["update"])

    def test_missing_release_asset_fails_without_changing_package(self):
        with tempfile.TemporaryDirectory() as directory:
            package = Path(directory) / "fixture.nix"
            original = 'version = "1.0.0"; hash = "sha256-old";\n'
            package.write_text(original)
            result = subprocess.run(
                [
                    "bash", "-c",
                    'set -euo pipefail; source "$1"; '
                    'curl() { return 22; }; '
                    'update_simple_sri fixture "$2" 2.0.0 https://example.invalid/asset',
                    "test", str(ROOT / "scripts/pkg-update.sh"), str(package),
                ],
                capture_output=True, text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(package.read_text(), original)

    def test_plugin_failures_are_reported_after_remaining_plugins(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            log = root / "calls"
            claude = root / "claude"
            claude.write_text(
                '#!/bin/bash\nprintf "%s\\n" "$*" >> "$TEST_PLUGIN_LOG"\n'
                'if [[ "$*" == "plugin update bad@fixture" ]]; then exit 23; fi\n'
            )
            claude.chmod(0o755)
            # Supply a fixture registry through jq; never read the user's plugin state.
            jq = root / "jq"
            jq.write_text('#!/bin/bash\nprintf "bad@fixture\\ngood@fixture\\n"\n')
            jq.chmod(0o755)
            result = subprocess.run(
                ["bash", str(ROOT / "scripts/ai-plugins-update.sh")],
                env={**os.environ, "PATH": f"{root}:{os.environ['PATH']}",
                     "TEST_PLUGIN_LOG": str(log)},
                capture_output=True, text=True,
            )
            self.assertEqual(log.read_text().splitlines(), [
                "plugin marketplace update", "plugin update bad@fixture",
                "plugin update good@fixture",
            ])
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn("Done!", result.stdout)


if __name__ == "__main__":
    unittest.main()
