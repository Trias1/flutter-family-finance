// Client-side backoff after failed sign-ins. Firebase Auth already rate-limits
// on its side (auth/too-many-requests); this slows a person or script driving
// the form and survives page reloads.

const KEY = "ff_login_throttle"

type State = { failures: number; lockedUntil: number }

function read(): State {
  try {
    const raw = window.localStorage.getItem(KEY)
    if (!raw) return { failures: 0, lockedUntil: 0 }
    const parsed = JSON.parse(raw) as Partial<State>
    return { failures: Number(parsed.failures) || 0, lockedUntil: Number(parsed.lockedUntil) || 0 }
  } catch {
    return { failures: 0, lockedUntil: 0 }
  }
}

function write(state: State) {
  try {
    window.localStorage.setItem(KEY, JSON.stringify(state))
  } catch {
    // Storage blocked; the in-memory countdown still applies for this page.
  }
}

// 3 failures -> 15s, then doubles each time, capped at 15 minutes.
function lockDurationMs(failures: number) {
  if (failures < 3) return 0
  return Math.min(15_000 * 2 ** (failures - 3), 15 * 60_000)
}

/** Seconds left on the current lock, 0 when not locked. */
export function getLockRemaining() {
  return Math.max(0, Math.ceil((read().lockedUntil - Date.now()) / 1000))
}

/** Records a failed attempt and returns the resulting lock in seconds. */
export function recordFailure() {
  const failures = read().failures + 1
  const lockedUntil = Date.now() + lockDurationMs(failures)
  write({ failures, lockedUntil })
  return Math.max(0, Math.ceil((lockedUntil - Date.now()) / 1000))
}

export function clearFailures() {
  try {
    window.localStorage.removeItem(KEY)
  } catch {
    // ignore
  }
}
