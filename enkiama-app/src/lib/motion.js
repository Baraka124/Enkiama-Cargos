// ENKIAMA MOTION SYSTEM V7
// Progressive enhancement only: native View Transitions where available,
// IntersectionObserver reveals, and helpers for shared visual continuity.

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
      el.classList.add('en-reveal')
      const delay = Number(binding.value?.delay ?? binding.value ?? 0)
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
      }, { threshold: 0.12, rootMargin: '0px 0px -7% 0px' })

      observer.observe(el)
      el._enRevealObserver = observer
    },
    unmounted(el) {
      el._enRevealObserver?.disconnect?.()
      delete el._enRevealObserver
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
