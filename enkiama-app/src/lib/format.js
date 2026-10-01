// ENKIAMA V23 — defensive presentation formatters.
// Public data can be incomplete or malformed; formatting must never leak NaN/Infinity/Invalid Date into the UI.
export function finiteNumber(value, fallback = null) {
  if (value === null || value === undefined || value === '') return fallback
  const n = Number(value)
  return Number.isFinite(n) ? n : fallback
}

export function formatNumber(value, options = {}) {
  const { fallback = '—', maximumFractionDigits = 0, minimumFractionDigits = 0 } = options
  const n = finiteNumber(value)
  if (n === null) return fallback
  try {
    return new Intl.NumberFormat('en-US', { maximumFractionDigits, minimumFractionDigits }).format(n)
  } catch (_) {
    return String(Math.round(n))
  }
}

export function formatTZS(value, options = {}) {
  const { fallback = '—', maximumFractionDigits = 0 } = options
  const n = finiteNumber(value)
  return n === null ? fallback : `TZS ${formatNumber(n, { fallback, maximumFractionDigits })}`
}

export function formatDateTime(value, options = {}) {
  if (!value) return options.fallback ?? ''
  const d = value instanceof Date ? value : new Date(value)
  if (Number.isNaN(d.getTime())) return options.fallback ?? ''
  try {
    return d.toLocaleString(options.locale || 'en-GB', options.format)
  } catch (_) {
    return d.toISOString()
  }
}
