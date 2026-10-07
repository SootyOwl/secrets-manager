#!/usr/bin/env python3
"""Secrets: store API keys in the desktop keyring and link them to programs.

Links are lines of `program VARIABLE secret-name` in secret-links.conf, read by
bin/with-secrets and shell/secret-links.bash.
"""
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

import gi

gi.require_version("Secret", "1")
from gi.repository import GLib, Secret  # noqa: E402

from PySide6.QtCore import Property, QObject, QUrl, Signal, Slot  # noqa: E402
from PySide6.QtGui import QIcon  # noqa: E402
from PySide6.QtQml import QQmlApplicationEngine  # noqa: E402
from PySide6.QtQuickControls2 import QQuickStyle  # noqa: E402
from PySide6.QtWidgets import QApplication  # noqa: E402

CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
LINKS = CONFIG / "secret-links.conf"
NAME_RE = re.compile(r"[A-Za-z0-9._-]+")
PROGRAM_RE = NAME_RE
VARIABLE_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")

# DONT_MATCH_NAME keeps items interchangeable with `secret-tool lookup service NAME`,
# which doesn't set a schema attribute.
SCHEMA = Secret.Schema.new(
    "org.freedesktop.Secret.Generic",
    Secret.SchemaFlags.DONT_MATCH_NAME,
    {"service": Secret.SchemaAttributeType.STRING, "app": Secret.SchemaAttributeType.STRING},
)
# Tagging our items is what lets us list them; the keyring has no "list all".
TAG = {"app": "secrets-manager"}


def read_links():
    try:
        lines = LINKS.read_text().splitlines()
    except FileNotFoundError:
        return []
    rows = (line.split() for line in lines if not line.lstrip().startswith("#"))
    return [tuple(r) for r in rows if len(r) == 3]


def write_links(links):
    LINKS.parent.mkdir(parents=True, exist_ok=True)
    tmp = LINKS.with_name(LINKS.name + ".tmp")
    tmp.write_text(
        "# program VARIABLE secret-name (managed by the Secrets app)\n"
        + "".join(f"{p} {v} {s}\n" for p, v, s in links)
    )
    tmp.replace(LINKS)


def suggest_variable(name):
    var = re.sub(r"[^A-Z0-9]", "_", name.upper()).strip("_")
    if not var:
        return ""
    if var[0].isdigit():
        var = "_" + var
    if not re.search(r"_(KEY|TOKEN|SECRET|PASSWORD)$", var):
        var += "_API_KEY"
    return var


class Backend(QObject):
    changed = Signal()

    def __init__(self):
        super().__init__()
        self._secrets = []
        self._links = []
        self._names = []
        self._error = ""
        self.refresh()

    def _get_secrets(self):
        return self._secrets

    def _get_links(self):
        return self._links

    def _get_names(self):
        return self._names

    def _get_error(self):
        return self._error

    secrets = Property("QVariantList", _get_secrets, notify=changed)
    links = Property("QVariantList", _get_links, notify=changed)
    secretNames = Property("QVariantList", _get_names, notify=changed)
    loadError = Property(str, _get_error, notify=changed)

    @Slot()
    def refresh(self):
        try:
            items = Secret.password_search_sync(
                SCHEMA, TAG, Secret.SearchFlags.ALL | Secret.SearchFlags.UNLOCK, None
            )
            names = sorted({i.get_attributes().get("service") for i in items} - {None})
            self._error = ""
        except GLib.Error as e:
            names = []
            self._error = f"Couldn't read the keyring: {e.message}"
        links = read_links()
        self._names = names
        self._secrets = [
            {"name": n, "usedBy": ", ".join(sorted({p for p, _, s in links if s == n}))}
            for n in names
        ]
        self._links = [
            {"program": p, "variable": v, "secret": s, "missing": s not in names}
            for p, v, s in sorted(links)
        ]
        self.changed.emit()

    @Slot(str, result=bool)
    def validName(self, name):
        return bool(NAME_RE.fullmatch(name))

    @Slot(str, result=bool)
    def validVariable(self, var):
        return bool(VARIABLE_RE.fullmatch(var))

    @Slot(str, result=bool)
    def exists(self, name):
        return name in self._names

    @Slot(str, result=bool)
    def onPath(self, program):
        return bool(PROGRAM_RE.fullmatch(program)) and shutil.which(program) is not None

    @Slot(str, result=str)
    def suggestVariable(self, name):
        return suggest_variable(name)

    @Slot(str, str, result=str)
    def storeSecret(self, name, value):
        if not NAME_RE.fullmatch(name) or not value:
            return "Enter a valid name and a value."
        try:
            # Clear first so an untagged item stored by secret-tool doesn't linger beside ours.
            Secret.password_clear_sync(SCHEMA, {"service": name}, None)
            Secret.password_store_sync(
                SCHEMA, {"service": name, **TAG}, Secret.COLLECTION_DEFAULT, name, value, None
            )
        except GLib.Error as e:
            return e.message
        finally:
            self.refresh()
        return ""

    @Slot(str, result=str)
    def deleteSecret(self, name):
        try:
            Secret.password_clear_sync(SCHEMA, {"service": name}, None)
        except GLib.Error as e:
            self.refresh()
            return e.message
        write_links([l for l in read_links() if l[2] != name])
        self.refresh()
        return ""

    @Slot(str, str, str, str, str, result=str)
    def saveLink(self, secret, program, variable, old_program, old_variable):
        if not PROGRAM_RE.fullmatch(program):
            return "Enter just the command name, e.g. borealis."
        if not VARIABLE_RE.fullmatch(variable):
            return f"“{variable}” isn't a valid variable name."
        drop = {(program, variable), (old_program, old_variable)}
        links = [l for l in read_links() if (l[0], l[1]) not in drop]
        write_links(links + [(program, variable, secret)])
        self.refresh()
        return ""

    @Slot(str, str)
    def removeLink(self, program, variable):
        write_links([l for l in read_links() if (l[0], l[1]) != (program, variable)])
        self.refresh()

    @Slot(result=str)
    def openWallet(self):
        for cmd in ("kwalletmanager5", "kwalletmanager"):
            if shutil.which(cmd):
                subprocess.Popen([cmd], start_new_session=True)
                return ""
        return "KWallet Manager isn't installed."


def main():
    if not os.environ.get("QT_QUICK_CONTROLS_STYLE"):
        QQuickStyle.setStyle("org.kde.desktop")
    app = QApplication(sys.argv)
    app.setApplicationName("secrets-manager")
    app.setApplicationDisplayName("Secrets")
    app.setDesktopFileName("secrets-manager")
    app.setWindowIcon(QIcon.fromTheme("dialog-password"))

    backend = Backend()
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("backend", backend)
    engine.load(QUrl.fromLocalFile(str(Path(__file__).with_name("main.qml"))))
    if not engine.rootObjects():
        sys.exit(1)
    status = app.exec()
    # Tear down QML before the backend it binds to, or it logs null errors on exit.
    del engine
    sys.exit(status)


if __name__ == "__main__":
    main()
