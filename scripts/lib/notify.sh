# notify.sh — shared helper: run a task, report output to Telegram, and ping
# an Uptime Kuma push monitor (dead-man's-switch) if one is configured.
#
# Usage:  source /home/pi/scripts/lib/notify.sh
#         run_with_notify my_task_function
#
# Kuma wiring (optional): /home/pi/scripts/.kuma.env defines KUMA_URL and one
# KUMA_TOKEN_<function_name> per script. Missing file/token = Telegram only.
TELEGRAM_SCRIPT="/home/pi/scripts/send_to_telegram.py"
[ -f /home/pi/scripts/.kuma.env ] && source /home/pi/scripts/.kuma.env

run_with_notify() {
  local name="$1" output rc
  output=$("$@" 2>&1); rc=$?
  printf '%s\n' "$output" | python3 "$TELEGRAM_SCRIPT"

  local tokvar="KUMA_TOKEN_${name}" token
  token="${!tokvar}"
  if [[ -n "$token" && -n "$KUMA_URL" ]]; then
    local status=up msg=OK
    [[ $rc -ne 0 ]] && { status=down; msg="exit_code_$rc"; }
    curl -fsS -m 10 "$KUMA_URL/api/push/$token?status=$status&msg=$msg" >/dev/null 2>&1 \
      || printf '⚠️ Kuma push failed for %s\n' "$name" | python3 "$TELEGRAM_SCRIPT"
  fi
  return $rc
}
