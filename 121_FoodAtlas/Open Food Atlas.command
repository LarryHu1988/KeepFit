#!/bin/zsh
set -eu
cd -- "${0:A:h}"
if /usr/bin/curl --silent --fail --max-time 2 http://127.0.0.1:8768/api/stats >/dev/null; then
    /usr/bin/open http://127.0.0.1:8768
    exit 0
fi
/usr/bin/python3 browser.py --port 8768 &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true' EXIT INT TERM
for attempt in {1..50}; do
    if /usr/bin/curl --silent --fail --max-time 1 http://127.0.0.1:8768/api/stats >/dev/null; then
        /usr/bin/open http://127.0.0.1:8768
        wait "$server_pid"
        exit 0
    fi
    sleep 0.1
done
print 'Unable to start Food Atlas. Check the message above.'
wait "$server_pid"
