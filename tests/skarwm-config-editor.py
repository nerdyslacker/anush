#!/usr/bin/env python3
"""Regression checks for recursive skarwm rc imports in the GUI helper."""

from __future__ import annotations

import copy
from importlib.machinery import SourceFileLoader
from pathlib import Path
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True
editor = SourceFileLoader(
    "anush_skarwm_config_editor",
    str(ROOT / "shell/scripts/skarwm/config-editor"),
).load_module()


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="anush-skarwm-editor-") as directory:
        base = Path(directory)
        config = base / "skarwm.rc"
        config_d = base / "config.d"
        config_d.mkdir()
        bindings = config_d / "keybindings.rc"
        rules = config_d / "rules.rc"
        config.write_text(
            "mod_key : super\n"
            "import : config.d/keybindings.rc\n"
            "import : config.d/rules.rc\n"
            "call : mod + q : close_window\n",
            encoding="utf-8",
        )
        bindings.write_text(
            "call : mod + Return : togglefloating\n",
            encoding="utf-8",
        )
        rules.write_text(
            'rule : class : "Picture-in-Picture" : floating\n',
            encoding="utf-8",
        )

        document = editor.parse(config)
        assert len(document["bindings"]) == 2
        assert len(document["rules"]) == 1
        imported = document["bindings"][0]
        assert imported["_source"] == str(bindings.resolve())

        changed = copy.deepcopy(document)
        changed["bindings"][0]["value"] = "togglefullscreen"
        differing = [
            source for source in document["_sources"]
            if editor.serialize_source(changed, source)
            != document["_serialized"][source]
        ]
        assert differing == [str(bindings.resolve())]

        editor.active_path = lambda: config
        saved = editor.save(changed, False)
        assert "togglefullscreen" in bindings.read_text(encoding="utf-8")
        main_text = config.read_text(encoding="utf-8")
        assert "import : config.d/keybindings.rc" in main_text
        assert "togglefullscreen" not in main_text
        assert len(saved["bindings"]) == 2

        rules.write_text("import : ../skarwm.rc\n", encoding="utf-8")
        try:
            editor.parse(config)
        except ValueError as failure:
            assert "import cycle" in str(failure)
        else:
            raise AssertionError("recursive import cycle was accepted")

    print("skarwm config editor import tests passed")


if __name__ == "__main__":
    main()
