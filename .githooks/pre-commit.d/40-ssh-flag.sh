#!/usr/bin/env bash
# Every direct `ssh host …` call must include `-o RemoteCommand=none`.
# Without it, ssh dies with "Cannot execute command-line and remote command"
# whenever the user's ssh_config sets a default RemoteCommand for that host.
# Array-indirected forms ("${HUB2_SSH[@]}") are not flagged here — the array
# definition itself is what we lint.
set -euo pipefail
LC_ALL=C

fails=0
while IFS= read -r f; do
  [[ "$f" == *.sh ]] || continue
  [[ -f "$f" ]] || continue
  awk '
    /^[[:space:]]*#/ { next }
    /\bssh\b/ && !/RemoteCommand=none/ && !/\bscp\b/ && !/sshpass/ {
      printf "%s:%d: ssh missing -o RemoteCommand=none → %s\n", FILENAME, NR, $0
      bad = 1
    }
    END { exit bad ? 1 : 0 }
  ' "$f" || fails=1
done <<<"$STAGED"

exit "$fails"
