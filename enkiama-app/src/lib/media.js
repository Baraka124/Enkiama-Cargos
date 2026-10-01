export function validMediaUrl(value) {
  const s = String(value || '').trim()
  return !!s && s !== 'null' && (s.startsWith('http://') || s.startsWith('https://') || s.startsWith('/'))
}

export function mediaList(entity, keys = ['images', 'image_url']) {
  if (!entity) return []
  const out = []
  const add = value => {
    if (validMediaUrl(value) && !out.includes(String(value).trim())) out.push(String(value).trim())
  }
  for (const key of keys) {
    const value = entity[key]
    if (Array.isArray(value)) value.forEach(add)
    else add(value)
  }
  return out
}

export function firstMedia(entity, keys = ['images', 'image_url']) {
  return mediaList(entity, keys)[0] || ''
}
