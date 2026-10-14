#!/usr/bin/env bash
# Windows build: build/windows/caretaker.exe + caretaker.pck. See tools/build/README.md.
exec bash "$(dirname "$0")/export.sh" windows "$@"
