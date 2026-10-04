import { createRouter, createWebHashHistory } from 'vue-router'
import { useAuth } from '../composables/useAuth'

const routes = [
  { path: '/', name: 'home', component: () => import('../views/LandingView.vue'), meta: { public: true, homeGate: true } },
  { path: '/login', name: 'login', component: () => import('../views/LoginView.vue'), meta: { public: true } },
  { path: '/property', name: 'property', component: () => import('../views/PropertyView.vue'), meta: { public: true } },
  { path: '/property/:id', name: 'property-detail', component: () => import('../views/PropertyDetailView.vue'), meta: { public: true } },
  { path: '/driver/apply', name: 'driver-apply', component: () => import('../views/DriverApplyView.vue'), meta: { public: true } },
  { path: '/join/:audience', name: 'join', component: () => import('../views/JoinView.vue'), meta: { public: true } },
  { path: '/join-driver', name: 'join-driver', component: () => import('../views/JoinDriverView.vue'), meta: { public: true } },
  { path: '/track/:code?', name: 'track', component: () => import('../views/TrackView.vue'), meta: { public: true } },
  { path: '/welcome', name: 'no-profile', component: () => import('../views/NoProfileView.vue') },
  { path: '/platform', name: 'platform', component: () => import('../views/PlatformView.vue'), meta: { platform: true } },
  { path: '/dispatch', name: 'dispatch', component: () => import('../views/DispatchView.vue'), meta: { roles: ['dispatch','carrier_admin'] } },
  { path: '/driver', name: 'driver', component: () => import('../views/DriverView.vue'), meta: { roles: ['driver'] } },
  { path: '/send', name: 'send', component: () => import('../views/SenderView.vue'), meta: { roles: ['sender'] } },
  { path: '/deliveries', name: 'deliveries', component: () => import('../views/ReceiverView.vue'), meta: { roles: ['receiver'] } },
  { path: '/market', name: 'market', component: () => import('../views/MarketplaceView.vue'), meta: { public: true } },
  { path: '/shop/:slug', name: 'shop', component: () => import('../views/StorefrontView.vue'), meta: { public: true } },
  { path: '/shop/:slug/product/:id', name: 'product', component: () => import('../views/ProductDetailView.vue'), meta: { public: true } },
  { path: '/property-deal/:id', name: 'property-deal', component: () => import('../views/PropertyDealView.vue') },
  { path: '/my-shop', name: 'my-shop', component: () => import('../views/StorefrontManageView.vue') },
  { path: '/reset', name: 'reset', component: () => import('../views/ResetView.vue'), meta: { public: true } },
  { path: '/account', name: 'account', component: () => import('../views/AccountView.vue') },
  { path: '/:pathMatch(.*)*', name: 'not-found', component: () => import('../views/NotFoundView.vue'), meta: { public: true } },
]

const router = createRouter({
  history: createWebHashHistory(),
  routes,
  scrollBehavior(to, from, savedPosition) {
    if (savedPosition) return savedPosition
    if (to.hash) return { el: to.hash, top: 12, behavior: window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth' }
    return { top: 0, left: 0 }
  },
})

const EXPERIENCE_WORLD = {
  market:'market', product:'object', property:'place', 'property-detail':'place', 'property-deal':'place',
  shop:'business', 'my-shop':'business', send:'business',
  track:'movement', deliveries:'movement',
}
// V10 — each public world has its own material atmosphere. Keep browser chrome
// in sync on mobile so the experience does not end at the viewport edge.

const ROUTE_TITLE = {
  home:'Enkiama Cargos', login:'Sign in · Enkiama', market:'Market · Enkiama', product:'Product · Enkiama',
  shop:'Business · Enkiama', property:'Property · Enkiama', 'property-detail':'Property · Enkiama',
  track:'Track · Enkiama', deliveries:'My Movement · Enkiama', account:'Account · Enkiama',
  dispatch:'Dispatch · Enkiama', driver:'Driver · Enkiama', send:'Sender · Enkiama', platform:'Platform · Enkiama',
  reset:'Reset password · Enkiama', join:'Join · Enkiama', 'join-driver':'Join as driver · Enkiama',
  'driver-apply':'Driver application · Enkiama', 'property-deal':'Property purchase · Enkiama', 'my-shop':'My shop · Enkiama',
  'no-profile':'Welcome · Enkiama', 'not-found':'Page not found · Enkiama',
}

const WORLD_THEME_COLOR = {
  core:'#F2EFE8', market:'#EEE8DC', object:'#F5F2EB', place:'#EDE8DE',
  business:'#EFE3D3', movement:'#0C1714',
}
router.afterEach((to) => {
  if (typeof document === 'undefined') return
  const world = EXPERIENCE_WORLD[to.name] || 'core'
  document.title = ROUTE_TITLE[to.name] || 'Enkiama Cargos'
  document.documentElement.dataset.enWorld = world
  let meta = document.querySelector('meta[name="theme-color"]')
  if (!meta) {
    meta = document.createElement('meta')
    meta.name = 'theme-color'
    document.head.appendChild(meta)
  }
  meta.content = WORLD_THEME_COLOR[world] || WORLD_THEME_COLOR.core
})

router.beforeEach(async (to) => {
  try {
    return await resolveGuard(to)
  } catch (e) {
    // a guard error must never leave the app blank — allow navigation through
    return true
  }
})

async function resolveGuard(to) {
  const { session, profile, isPlatformAdmin, init, loading, reloadProfile } = useAuth()
  await init()
  let guard = 0
  while (loading.value && guard++ < 50) await new Promise(r => setTimeout(r, 40))

  const authed = !!session.value

  // The "home gate" (/) decides where a signed-in user actually belongs.
  if (to.meta.homeGate) {
    if (!authed) return true  // show the landing/login hero
    // ensure profile is loaded before deciding (guards the post-login race)
    if (!profile.value && !isPlatformAdmin.value) await reloadProfile()
    if (isPlatformAdmin.value) return { name: 'platform' }
    const r = profile.value?.role
    if (r === 'driver') return { name: 'driver' }
    if (r === 'sender') return { name: 'send' }
    if (r === 'receiver') return { name: 'deliveries' }
    if (r === 'carrier_admin' || r === 'dispatch') return { name: 'dispatch' }
    return { name: 'no-profile' }
  }

  if (to.meta.public) return true
  if (!authed) return to.name === 'login' ? true : { name: 'login' }

  // signed in but profile not yet loaded → try once more before judging
  if (!profile.value && !isPlatformAdmin.value) await reloadProfile()

  const role = profile.value?.role
  const pa = isPlatformAdmin.value

  // platform console: only platform admins
  if (to.meta.platform) {
    return pa ? true : { name: 'dispatch' }
  }

  // a platform admin with no carrier role still has a home: the console
  if (!role && pa) return { name: 'platform' }

  // genuinely no role and not a platform admin → not linked yet
  if (!role && !pa) {
    return to.name === 'no-profile' ? true : { name: 'no-profile' }
  }

  // role-scoped routes
  if (to.meta.roles && role && !to.meta.roles.includes(role)) {
    const home = role === 'driver' ? 'driver' : role === 'sender' ? 'send' : role === 'receiver' ? 'deliveries' : 'dispatch'
    return to.name === home ? true : { name: home }
  }
  return true
}

export default router
