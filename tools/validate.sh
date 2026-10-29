#!/usr/bin/env sh
# Valide les 10 niveaux. Usage : ./tools/validate.sh [chemin/vers/godot]
GODOT="${1:-${GODOT:-godot}}"
cd "$(dirname "$0")/.." || exit 1
# L'import crée le cache des classes (class_name) nécessaire au script.
"$GODOT" --headless --path . --import >/dev/null 2>&1
"$GODOT" --headless --path . --script res://tools/validate_levels.gd
