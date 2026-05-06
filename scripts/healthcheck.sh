#!/usr/bin/env bash
set -euo pipefail

readonly PING_TIMEOUT=3
readonly HTTP_TIMEOUT=5

log()   { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] INFO  $*"; }
err()   { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] ERROR $*" >&2; }
die()   { err "$@"; exit 1; }
usage() { echo "Usage: $0 [-p port] <hostname>" >&2; exit 2; }

check_prerequisites() {
    local missing=()
    for cmd in curl ping; do
        command -v "$cmd" >/dev/null || missing+=("$cmd")
    done
    (( ${#missing[@]} == 0 )) || die "Thiếu tool: ${missing[*]}"
}

check_ping() {
    local host=$1
    # ping -W: per-packet wait; -c 1: one packet; timeout bounds total wall time
    if timeout "$PING_TIMEOUT" ping -c 1 -W 2 "$host" &>/dev/null; then
        log "PING OK  — $host"
    else
        err "PING FAIL — $host unreachable"; return 1
    fi
}

check_http() {
    local host=$1 port=$2
    local code
    code=$(curl -sS --max-time "$HTTP_TIMEOUT" -o /dev/null -w "%{http_code}" \
        "http://${host}:${port}/health")
    [[ "$code" == "200" ]] || { err "HTTP FAIL — got $code from $host:$port"; return 1; }
    log "HTTP OK  — $host:$port returned $code"
}

main() {
    local port=80

    while getopts "p:h" opt; do
        case $opt in p) port=$OPTARG ;; *) usage ;; esac
    done
    shift $((OPTIND - 1))

    [[ $# -ge 1 ]]                           || usage
    [[ $port =~ ^[0-9]+$ ]]                  || die "port phải là số: '$port'"
    [[ $port -ge 1 && $port -le 65535 ]]     || die "port ngoài khoảng: $port"

    local host=$1
    local failed=0

    check_prerequisites
    check_ping "$host"       || failed=1
    check_http "$host" "$port" || failed=1

    (( failed == 0 )) && log "ALL OK — $host:$port" || err "FAILED — $host:$port"
    return "$failed"
}

main "$@"
