#!/usr/bin/env bash
# Mantle -- packaging only. There is no plugin any more: the one thing a DLL was
# needed for, spotting that the player has walked into something, is answered by
# Player Physics, which is the only code that can see both the speed the engine
# asked for and the distance actually covered.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
archive="$root/Mantle.zip"

for required in "$root/scripts-game" "$root/meshes" "$root/README.md" "$root/RESEARCH.md"; do
    [[ -e "$required" ]] || { echo "error: missing $required" >&2; exit 1; }
done

rm -rf "$root/nvse" "$archive"
mkdir -p "$root/nvse/Plugins/Scripts" "$root/nvse/user_defined_functions/Mantle"

cp "$root"/scripts-game/*.txt "$root/nvse/Plugins/Scripts/"
cp "$root"/scripts-game/udf/*.gek "$root/nvse/user_defined_functions/Mantle/"

# JIP will not precompile a script with unix line endings.
for f in "$root"/nvse/Plugins/Scripts/*.txt "$root"/nvse/user_defined_functions/Mantle/*.gek; do
    perl -pi -e 's/\r?\n/\r\n/' "$f"
done

(cd "$root" && zip -rq "$archive" nvse meshes README.md RESEARCH.md -x '*.DS_Store')

echo
echo "staged  $root/nvse/Plugins/Scripts/"
echo "        $root/nvse/user_defined_functions/Mantle/"
echo "        $root/meshes/"
echo "package $archive"
