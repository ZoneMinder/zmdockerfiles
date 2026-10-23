# Shared helpers for the init scripts. Sourced, not executed.
log()  { echo "[${0##*/}] $*"; }
die()  { echo "[${0##*/}] ERROR: $*" >&2; exit 1; }

ZM_DB_NAME="${ZM_DB_NAME:-zm}"
ZM_DB_USER="${ZM_DB_USER:-zmuser}"
ZM_DB_HOST="${ZM_DB_HOST:-db}"
if [[ -n "${ZM_DB_PASS_FILE:-}" ]]; then
    [[ -r "$ZM_DB_PASS_FILE" ]] || die "ZM_DB_PASS_FILE=$ZM_DB_PASS_FILE is not readable"
    ZM_DB_PASS="$(<"$ZM_DB_PASS_FILE")"
fi
MYCNF=/run/zm-docker/my.cnf

# Run a SQL statement against the ZM database; output is tab separated, no header.
sql() { mariadb --defaults-extra-file="$MYCNF" -N -B "$ZM_DB_NAME" -e "$1"; }
