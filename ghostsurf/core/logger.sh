#!/usr/bin/env bash
# logger.sh — logging unifié avec niveaux et couleurs

_gs_log() {
    local level=$1 color=$2 msg=$3
    local ts; ts=$(date '+%H:%M:%S')
    local reset='\033[0m'
    if [[ -t 2 ]]; then
        echo -e "${color}[${ts}] [${level}]${reset} ${msg}" >&2
    else
        echo "[${ts}] [${level}] ${msg}" >&2
    fi
    # Journal dans le state dir si disponible
    if [[ -d "${STATE_DIR:-/var/lib/ghostsurf}" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] ${msg}" \
            >> "${STATE_DIR}/ghostsurf.log" 2>/dev/null || true
    fi
}

log_info()    { _gs_log "INFO " '\033[0;34m' "$*"; }
log_success() { _gs_log "OK   " '\033[0;32m' "$*"; }
log_warn()    { _gs_log "WARN " '\033[0;33m' "$*"; }
log_error()   { _gs_log "ERROR" '\033[0;31m' "$*"; }
log_debug()   {
    [[ "${GHOSTSURF_VERBOSE:-false}" == "true" ]] || return 0
    _gs_log "DEBUG" '\033[0;35m' "$*"
}
