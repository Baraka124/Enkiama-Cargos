// ENKIAMA MOTION SYSTEM V19
// Motion communicates continuity, hierarchy and state. It never decorates forms,
// checkout or operational controls. Native View Transitions remain progressive
// enhancement; depth is disabled for reduced-motion and coarse-pointer users.

export function prefersReducedMotion() {
  return typeof window !== 'undefined' && !!window.matchMedia?.('(prefers-reduced-motion: reduce)').matches
}

export function supportsViewTransitions() {
  return typeof document !== 'undefined' && typeof document.startViewTransition === 'function' && !prefersReducedMotion()
}

export function viewName(kind, id) {
  if (id === null || id === undefined || id === '') return 'none'
  const safe = String(id).toLowerCase().replace(/[^a-z0-9_-]+/g, '-').replace(/^-+|-+$/g, '')
  return safe ? `enkiama-${kind}-${safe}` : 'none'
}

export function signalMotionReady() {
  if (typeof window === 'undefined') return
  const fullPath = (window.location.hash || '#/').replace(/^#/, '') || '/'
  window.dispatchEvent(new CustomEvent('enkiama:motion-ready', { detail: { fullPath } }))
}

function waitForMotionReady(fullPath, timeout = 380) {
  if (typeof window === 'undefined') return Promise.resolve()
  return new Promise((resolve) => {
    let timer = null
    const done = () => {
      window.removeEventListener('enkiama:motion-ready', onReady)
      if (timer) clearTimeout(timer)
      resolve()
    }
    const onReady = (event) => {
      if (!fullPath || event?.detail?.fullPath === fullPath) done()
    }
    window.addEventListener('enkiama:motion-ready', onReady)
    timer = setTimeout(done, timeout)
  })
}

export function installRevealDirective(app) {
  app.directive('reveal', {
    mounted(el, binding) {
      const value = binding.value
      const config = value && typeof value === 'object' ? value : { delay: value }
      const delay = Number(config?.delay ?? 0)
      const variant = ['copy','media','line','section'].includes(config?.variant) ? config.variant : 'section'

      el.classList.add('en-reveal')
      el.dataset.enReveal = variant
      if (Number.isFinite(delay) && delay > 0) el.style.setProperty('--en-reveal-delay', `${Math.min(delay, 420)}ms`)

      if (prefersReducedMotion() || typeof IntersectionObserver === 'undefined') {
        el.classList.add('en-revealed')
        return
      }

      const observer = new IntersectionObserver((entries) => {
        for (const entry of entries) {
          if (!entry.isIntersecting) continue
          entry.target.classList.add('en-revealed')
          observer.unobserve(entry.target)
        }
      }, { threshold: variant === 'media' ? 0.08 : 0.12, rootMargin: '0px 0px -7% 0px' })

      observer.observe(el)
      el._enRevealObserver = observer
    },
    unmounted(el) {
      el._enRevealObserver?.disconnect?.()
      delete el._enRevealObserver
    },
  })
}

// ─────────────────────────────────────────────────────────────
// SPATIAL DEPTH
// One RAF loop drives all registered elements. Values are intentionally tiny:
// foreground objects feel physical without becoming mouse-following gimmicks.
// ─────────────────────────────────────────────────────────────
const depthEntries = new Set()
let depthRaf = 0
let pointerX = 0
let pointerY = 0
let controllerInstalled = false
let finePointer = false

function clamp(value, min, max) { return Math.min(max, Math.max(min, value)) }

function depthConfig(value) {
  const v = value && typeof value === 'object' ? value : {}
  const amount = clamp(Number(v.amount ?? value ?? 1) || 1, .25, 3)
  return {
    amount,
    pointer: clamp(Number(v.pointer ?? 4 * amount) || 0, 0, 12),
    scroll: clamp(Number(v.scroll ?? 8 * amount) || 0, 0, 22),
    rotate: clamp(Number(v.rotate ?? .38 * amount) || 0, 0, 1.2),
    scale: clamp(Number(v.scale ?? (1 + .004 * amount)) || 1, 1, 1.025),
    invert: v.invert === true ? -1 : 1,
  }
}

function motionAllowed() {
  if (typeof window === 'undefined') return false
  return !prefersReducedMotion() && window.matchMedia?.('(pointer:fine)').matches && window.innerWidth >= 860
}

function resetDepth(el) {
  el.style.setProperty('--en-depth-x', '0px')
  el.style.setProperty('--en-depth-y', '0px')
  el.style.setProperty('--en-depth-rx', '0deg')
  el.style.setProperty('--en-depth-ry', '0deg')
}

function renderDepth() {
  depthRaf = 0
  finePointer = motionAllowed()
  const width = Math.max(window.innerWidth, 1)
  const height = Math.max(window.innerHeight, 1)
  const px = clamp(pointerX / width * 2 - 1, -1, 1)
  const py = clamp(pointerY / height * 2 - 1, -1, 1)

  for (const entry of depthEntries) {
    const { el, config } = entry
    if (!el?.isConnected) continue
    if (!finePointer) { resetDepth(el); continue }

    const rect = el.getBoundingClientRect()
    if (rect.bottom < -height * .35 || rect.top > height * 1.35) continue

    const center = rect.top + rect.height / 2
    const phase = clamp((center - height / 2) / (height * .78), -1, 1)
    const inv = config.invert
    const x = px * config.pointer * inv
    const y = (py * config.pointer * .42 - phase * config.scroll) * inv
    const rx = -py * config.rotate
    const ry = px * config.rotate * inv

    el.style.setProperty('--en-depth-x', `${x.toFixed(2)}px`)
    el.style.setProperty('--en-depth-y', `${y.toFixed(2)}px`)
    el.style.setProperty('--en-depth-rx', `${rx.toFixed(3)}deg`)
    el.style.setProperty('--en-depth-ry', `${ry.toFixed(3)}deg`)
    el.style.setProperty('--en-depth-scale', String(config.scale))
  }
}

function queueDepth() {
  if (!depthRaf) depthRaf = requestAnimationFrame(renderDepth)
}

function installDepthController() {
  if (controllerInstalled || typeof window === 'undefined') return
  controllerInstalled = true
  pointerX = window.innerWidth / 2
  pointerY = window.innerHeight / 2

  window.addEventListener('pointermove', (event) => {
    pointerX = event.clientX
    pointerY = event.clientY
    queueDepth()
  }, { passive: true })
  window.addEventListener('scroll', queueDepth, { passive: true })
  window.addEventListener('resize', queueDepth, { passive: true })
  document.addEventListener('mouseleave', () => {
    pointerX = window.innerWidth / 2
    pointerY = window.innerHeight / 2
    queueDepth()
  })
}

export function installSpatialDepthDirective(app) {
  installDepthController()
  app.directive('depth', {
    mounted(el, binding) {
      const entry = { el, config: depthConfig(binding.value) }
      el.classList.add('en-depth')
      el._enDepthEntry = entry
      depthEntries.add(entry)
      resetDepth(el)
      queueDepth()
    },
    updated(el, binding) {
      if (el._enDepthEntry) el._enDepthEntry.config = depthConfig(binding.value)
      queueDepth()
    },
    unmounted(el) {
      if (el._enDepthEntry) depthEntries.delete(el._enDepthEntry)
      delete el._enDepthEntry
      el.classList.remove('en-depth')
      resetDepth(el)
    },
  })
}

export function installRouterViewTransitions(router) {
  if (!supportsViewTransitions()) return

  const rawPush = router.push.bind(router)
  const rawReplace = router.replace.bind(router)
  let running = false

  const readyRoutes = new Set(['market','product','property','property-detail','shop','track','deliveries'])

  const wrap = (navigate) => (to) => {
    if (running || prefersReducedMotion() || !router.currentRoute.value?.matched?.length) return navigate(to)

    const target = router.resolve(to)
    const ready = readyRoutes.has(target.name) ? waitForMotionReady(target.fullPath) : Promise.resolve()

    return new Promise((resolve, reject) => {
      running = true
      document.documentElement.classList.add('en-native-transition')

      let transition
      try {
        transition = document.startViewTransition(async () => {
          try {
            const result = await navigate(to)
            await ready
            await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)))
            resolve(result)
            return result
          } catch (error) {
            reject(error)
            throw error
          }
        })
      } catch (error) {
        running = false
        document.documentElement.classList.remove('en-native-transition')
        navigate(to).then(resolve, reject)
        return
      }

      transition.finished.catch(() => {}).finally(() => {
        running = false
        document.documentElement.classList.remove('en-native-transition')
      })
    })
  }

  router.push = wrap(rawPush)
  router.replace = wrap(rawReplace)
}
