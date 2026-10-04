#!/bin/bash

set -euo pipefail

service_state="$(launchctl print system/com.apple.ifdreader 2>/dev/null || true)"
service_pid="$(printf '%s\n' "$service_state" | awk '/^[[:space:]]*pid = / { print $3; exit }')"

if [[ -z "$service_pid" ]]; then
	echo "The smart-card service is not running. Disconnect the reader, wait five seconds, then reconnect it."
	exit 0
fi

if ! [[ "$service_pid" =~ ^[0-9]+$ ]]; then
	echo "Could not determine a safe smart-card service PID." >&2
	exit 1
fi

echo "Stopping com.apple.ifdreader (PID $service_pid)..."
sudo kill -KILL "$service_pid"
echo "Disconnect the reader, wait five seconds, reconnect it, then insert the card."
