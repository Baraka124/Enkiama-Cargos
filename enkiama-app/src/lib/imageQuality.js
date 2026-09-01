// Lightweight, in-browser image quality analysis — no external service.
// Measures real signals from the pixels and returns human advice so shops
// upload photos that make the marketplace look elite.

export async function analyzeImage(fileOrUrl) {
  const img = await loadImage(fileOrUrl)
  const width = img.naturalWidth
  const height = img.naturalHeight

  // draw to a downscaled canvas for fast analysis (sharpness/brightness don't need full res)
  const maxDim = 512
  const scale = Math.min(1, maxDim / Math.max(width, height))
  const cw = Math.max(1, Math.round(width * scale))
  const ch = Math.max(1, Math.round(height * scale))
  const canvas = document.createElement('canvas')
  canvas.width = cw; canvas.height = ch
  const ctx = canvas.getContext('2d', { willReadFrequently: true })
  ctx.drawImage(img, 0, 0, cw, ch)

  let data
  try { data = ctx.getImageData(0, 0, cw, ch).data }
  catch (e) { return { ok: true, unknown: true } } // cross-origin etc — skip gracefully

  // grayscale + brightness
  const gray = new Float32Array(cw * ch)
  let brightnessSum = 0
  for (let i = 0, p = 0; i < data.length; i += 4, p++) {
    const g = 0.299 * data[i] + 0.587 * data[i + 1] + 0.114 * data[i + 2]
    gray[p] = g
    brightnessSum += g
  }
  const brightness = brightnessSum / (cw * ch) / 255 // 0..1

  // sharpness via Laplacian variance (standard blur metric)
  let lapSum = 0, lapSqSum = 0, n = 0
  for (let y = 1; y < ch - 1; y++) {
    for (let x = 1; x < cw - 1; x++) {
      const idx = y * cw + x
      const lap = 4 * gray[idx] - gray[idx - 1] - gray[idx + 1] - gray[idx - cw] - gray[idx + cw]
      lapSum += lap; lapSqSum += lap * lap; n++
    }
  }
  const lapMean = lapSum / n
  const sharpnessVar = lapSqSum / n - lapMean * lapMean // higher = sharper

  const megapixels = (width * height) / 1e6
  const aspect = width / height

  // ── grade the signals into human advice ──
  const issues = []
  let severity = 'good' // good | warn | poor

  // resolution
  if (width < 500 || height < 500) {
    issues.push({ key: 'resolution', level: 'poor', msg: `Low resolution (${width}×${height}px). Use at least 800×800 so it stays crisp.` })
    severity = 'poor'
  } else if (width < 800 || height < 800) {
    issues.push({ key: 'resolution', level: 'warn', msg: `A bit small (${width}×${height}px). 1000×1000 or larger looks sharper.` })
    if (severity === 'good') severity = 'warn'
  }

  // sharpness / blur
  if (sharpnessVar < 80) {
    issues.push({ key: 'blur', level: 'poor', msg: 'Looks blurry. Hold steady, tap to focus, and retake in good light.' })
    severity = 'poor'
  } else if (sharpnessVar < 200) {
    issues.push({ key: 'blur', level: 'warn', msg: 'Slightly soft. A sharper photo will sell better.' })
    if (severity === 'good') severity = 'warn'
  }

  // brightness
  if (brightness < 0.22) {
    issues.push({ key: 'dark', level: 'warn', msg: 'Quite dark. Shoot near a window or in daylight.' })
    if (severity === 'good') severity = 'warn'
  } else if (brightness > 0.9) {
    issues.push({ key: 'bright', level: 'warn', msg: 'Overexposed / washed out. Avoid direct glare.' })
    if (severity === 'good') severity = 'warn'
  }

  // aspect ratio — square is ideal for the grid; warn on extremes
  if (aspect > 2.2 || aspect < 0.45) {
    issues.push({ key: 'aspect', level: 'warn', msg: 'Very wide/tall — the grid crops to a square, so edges may be cut. A square photo shows best.' })
    if (severity === 'good') severity = 'warn'
  }

  return {
    ok: true,
    width, height, megapixels: Math.round(megapixels * 10) / 10,
    aspect: Math.round(aspect * 100) / 100,
    brightness: Math.round(brightness * 100) / 100,
    sharpness: Math.round(sharpnessVar),
    severity,   // good | warn | poor
    issues,     // [{key, level, msg}]
  }
}

function loadImage(fileOrUrl) {
  return new Promise((resolve, reject) => {
    const img = new Image()
    img.crossOrigin = 'anonymous'
    img.onload = () => resolve(img)
    img.onerror = reject
    if (typeof fileOrUrl === 'string') img.src = fileOrUrl
    else {
      const r = new FileReader()
      r.onload = () => { img.src = r.result }
      r.onerror = reject
      r.readAsDataURL(fileOrUrl)
    }
  })
}
