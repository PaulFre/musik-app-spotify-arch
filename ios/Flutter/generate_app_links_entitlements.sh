#!/bin/sh
set -e

OUTPUT_FILE="${SRCROOT}/Runner/GeneratedAppLinks.entitlements"
DEFAULT_BASE_URL="https://party-queue.example"
PUBLIC_APP_BASE_URL_VALUE="$DEFAULT_BASE_URL"

if [ -n "${DART_DEFINES}" ]; then
  PUBLIC_APP_BASE_URL_VALUE=$(python3 - "$DART_DEFINES" "$DEFAULT_BASE_URL" <<'PY'
import base64
import sys

encoded_values = sys.argv[1]
default_value = sys.argv[2]

for item in encoded_values.split(","):
    if not item:
        continue
    try:
        decoded = base64.b64decode(item).decode("utf-8")
    except Exception:
        continue
    if decoded.startswith("PUBLIC_APP_BASE_URL="):
        print(decoded.split("=", 1)[1])
        break
else:
    print(default_value)
PY
)
fi

APP_LINK_HOST=$(python3 - "$PUBLIC_APP_BASE_URL_VALUE" <<'PY'
import sys
from urllib.parse import urlparse

value = sys.argv[1]
parsed = urlparse(value)
print(parsed.hostname or "party-queue.example")
PY
)

cat > "$OUTPUT_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.associated-domains</key>
	<array>
		<string>applinks:${APP_LINK_HOST}</string>
	</array>
</dict>
</plist>
EOF
