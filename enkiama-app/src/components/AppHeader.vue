<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import BrandMark from './BrandMark.vue'
import CarrierMark from './CarrierMark.vue'
import Avatar from './Avatar.vue'
import Icon from './Icon.vue'
import { useAuth } from '../composables/useAuth'
import { supabase } from '../lib/supabase'

const props = defineProps({
  title: { type: String, default: '' },
  subtitle: { type: String, default: '' },
  carrier: { type: Object, default: null },
  live: { type: Boolean, default: false },
  market: { type: Boolean, default: true },
  auth: { type: Boolean, default: true },
})

const router = useRouter()
const route = useRoute()
const { session, profile, signOut, isPlatformAdmin } = useAuth()
const menuOpen = ref(false)
const navOpen = ref(false)

const WORLD_BY_ROUTE = {
  market:'market', product:'object', property:'place', 'property-detail':'place', 'property-deal':'place',
  shop:'business', 'my-shop':'business', track:'movement', deliveries:'movement',
}
const LABEL_BY_WORLD = { market:'Market', object:'Object', place:'Property', business:'Business', movement:'Movement', core:'' }

const world = computed(() => WORLD_BY_ROUTE[route.name] || 'core')
const movement = computed(() => world.value === 'movement')
const contextTitle = computed(() => {
  const raw = (props.title || '').trim()
  if (raw && raw !== 'Enkiama Cargos') return raw.replace(/^Enkiama\s+/i, '')
  return LABEL_BY_WORLD[world.value] || ''
})
const showContext = computed(() => !!contextTitle.value && route.name !== 'home')

const isLoggedIn = computed(() => !!session?.value)
const displayName = computed(() => profile?.value?.name || session?.value?.user?.email?.split('@')[0] || 'Account')
const roleLabel = computed(() => {
  const r = profile?.value?.role
  const map = { carrier_admin: 'Carrier admin', dispatch: 'Dispatch', driver: 'Driver', sender: 'Business', receiver: 'Receiver' }
  return map[r] || (r ? r.replace('_', ' ') : '')
})
const homePath = computed(() => {
  const r = profile?.value?.role
  return r === 'driver' ? '/driver' : (r === 'dispatch' || r === 'carrier_admin') ? '/dispatch'
    : r === 'sender' ? '/send' : r === 'receiver' ? '/deliveries' : '/'
})

const primaryNav = [
  { to:'/market', label:'Market', match:['market','product','shop'] },
  { to:'/property', label:'Property', match:['property','property-detail','property-deal'] },
  { to:'/track', label:'Track', match:['track','deliveries'] },
]
function navActive(item) { return item.match.includes(route.name) }
function closeSheets() { menuOpen.value = false; navOpen.value = false }
async function doSignOut() { closeSheets(); await signOut(); router.push('/login') }

const myShop = ref(null)
onMounted(async () => {
  if (!session?.value?.user?.id) return
  try {
    const { data } = await supabase.from('storefront').select('slug,name').eq('owner_id', session.value.user.id).maybeSingle()
    myShop.value = data || null
  } catch (e) {}
})
function isCurrent(path) { return route.path === path }
</script>

<template>
  <header class="ah" :class="[`ah--${world}`, {'ah--movement':movement}]">
    <div class="ah-inner">
      <button class="ah-brand" type="button" @click="router.push('/')" aria-label="Enkiama home">
        <template v-if="carrier">
          <CarrierMark :slug="carrier.slug" :mark="carrier.mark" :name="carrier.name" :accent="carrier.accent" :size="36" />
        </template>
        <BrandMark v-else variant="full" :height="27" :light="movement" />

        <span v-if="showContext" class="ah-context">
          <span class="ah-context-line" aria-hidden="true"></span>
          <span class="ah-context-copy">
            <strong>{{ contextTitle }}</strong>
            <small v-if="subtitle">{{ subtitle }}</small>
          </span>
        </span>
        <span v-if="live" class="ah-live"><span class="ah-live-dot"></span>Live</span>
      </button>

      <nav class="ah-primary" aria-label="Primary navigation">
        <RouterLink v-for="item in primaryNav" :key="item.to" :to="item.to" :class="{on:navActive(item)}">
          {{ item.label }}
        </RouterLink>
      </nav>

      <div class="ah-actions">
        <slot />

        <button class="ah-explore" type="button" @click="navOpen = !navOpen; menuOpen = false" :aria-expanded="navOpen">
          Explore <span aria-hidden="true">↘</span>
        </button>

        <template v-if="auth">
          <RouterLink v-if="!isLoggedIn" to="/login" class="ah-signin">Sign in</RouterLink>

          <div v-else class="ah-account">
            <button class="ah-chip" :class="{'ah-chip-admin': isPlatformAdmin}" @click="menuOpen = !menuOpen; navOpen = false" :aria-expanded="menuOpen">
              <Avatar :name="displayName" size="sm" />
              <span class="ah-chip-id">
                <span class="ah-chip-name">{{ displayName }}</span>
                <span v-if="isPlatformAdmin" class="ah-chip-role ah-admin-tag"><Icon name="shield" :size="10" /> Admin</span>
                <span v-else-if="roleLabel" class="ah-chip-role">{{ roleLabel }}</span>
              </span>
              <span class="ah-chip-caret" aria-hidden="true">↘</span>
            </button>

            <transition name="ah-menu">
              <div v-if="menuOpen" class="ah-menu" v-click-outside="() => menuOpen=false">
                <div class="ah-menu-handle" aria-hidden="true"></div>
                <div class="ah-menu-head">
                  <Avatar :name="displayName" />
                  <div>
                    <div class="ah-menu-name">{{ displayName }}<span v-if="isPlatformAdmin" class="ah-admin-tag ah-admin-tag-menu"><Icon name="shield" :size="10" /> Admin</span></div>
                    <div class="ah-menu-role">{{ session?.user?.email }}</div>
                  </div>
                </div>
                <div class="ah-menu-spaces-l">Workspace</div>
                <RouterLink :to="homePath" class="ah-menu-item ah-space" :class="{cur: isCurrent(homePath)}" @click="closeSheets">
                  <Icon name="display" :size="15" /> <span>{{ roleLabel || 'Dashboard' }}</span><span v-if="isCurrent(homePath)" class="ah-cur-dot"></span>
                </RouterLink>
                <RouterLink v-if="myShop" :to="`/shop/${myShop.slug}`" class="ah-menu-item ah-space" @click="closeSheets">
                  <Icon name="building" :size="15" /> <span>My shop · {{ myShop.name }}</span>
                </RouterLink>
                <div class="ah-menu-sep"></div>
                <RouterLink to="/account" class="ah-menu-item" @click="closeSheets"><Icon name="pen" :size="15" /> Account</RouterLink>
                <RouterLink to="/market" class="ah-menu-item" @click="closeSheets"><Icon name="box" :size="15" /> Market</RouterLink>
                <RouterLink to="/track" class="ah-menu-item" @click="closeSheets"><Icon name="pin" :size="15" /> Track a parcel</RouterLink>
                <div class="ah-menu-sep"></div>
                <button class="ah-menu-item danger" @click="doSignOut"><Icon name="signout" :size="15" /> Sign out</button>
              </div>
            </transition>
          </div>
        </template>
      </div>
    </div>

    <transition name="ah-menu">
      <div v-if="navOpen" class="ah-mobile-nav" v-click-outside="() => navOpen=false">
        <div class="ah-menu-handle" aria-hidden="true"></div>
        <div class="ah-mobile-label">Explore Enkiama</div>
        <RouterLink v-for="item in primaryNav" :key="item.to" :to="item.to" :class="{on:navActive(item)}" @click="navOpen=false">
          <span>{{ item.label }}</span><span aria-hidden="true">↗</span>
        </RouterLink>
        <RouterLink to="/join/business" @click="navOpen=false"><span>Sell with Enkiama</span><span aria-hidden="true">↗</span></RouterLink>
      </div>
    </transition>
  </header>
</template>

<style scoped>
.ah{position:sticky;top:0;z-index:80;color:var(--world-ink);background:color-mix(in srgb,var(--world-canvas) 88%,transparent);border-bottom:1px solid var(--world-line);backdrop-filter:blur(18px) saturate(125%);-webkit-backdrop-filter:blur(18px) saturate(125%);transition:background .35s var(--ease),border-color .35s var(--ease),color .35s var(--ease)}
.ah--movement{color:var(--world-ink);background:color-mix(in srgb,var(--world-nav) 86%,transparent);border-bottom-color:var(--world-nav-line)}
.ah-inner{width:min(var(--page-max),calc(100% - (var(--page-gutter) * 2)));min-height:72px;margin:0 auto;display:grid;grid-template-columns:minmax(220px,1fr) auto minmax(220px,1fr);align-items:center;gap:28px}
.ah-brand{justify-self:start;display:flex;align-items:center;gap:14px;min-width:0;padding:0;background:none;border:0;color:inherit;font:inherit;cursor:pointer;text-align:left}
.ah-context{display:flex;align-items:center;gap:12px;min-width:0}.ah-context-line{width:1px;height:28px;background:var(--world-line-strong);flex:0 0 auto}.ah--movement .ah-context-line{background:var(--world-nav-line)}
.ah-context-copy{display:flex;flex-direction:column;min-width:0;line-height:1.05}.ah-context-copy strong{font:600 12px/1.1 var(--font-display);letter-spacing:-.015em;color:inherit;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.ah-context-copy small{margin-top:4px;font:500 9px/1 var(--font-mono);text-transform:uppercase;letter-spacing:.09em;color:var(--world-ink-faint);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:230px}
.ah-live{display:inline-flex;align-items:center;gap:6px;margin-left:4px;padding:4px 8px;border-radius:999px;background:var(--world-accent-soft);color:var(--world-accent-ink);font:600 9px/1 var(--font-mono);text-transform:uppercase;letter-spacing:.06em}.ah-live-dot{width:5px;height:5px;border-radius:50%;background:currentColor;animation:ahPulse 2.2s var(--ease) infinite}@keyframes ahPulse{50%{opacity:.42;transform:scale(.75)}}

.ah-primary{display:flex;align-items:center;justify-content:center;gap:30px;height:100%}.ah-primary a{position:relative;display:flex;align-items:center;height:100%;color:var(--world-ink-faint);font:600 11px/1 var(--font-display);letter-spacing:.02em;text-decoration:none;transition:color .2s var(--ease)}.ah-primary a::after{content:"";position:absolute;left:0;right:0;bottom:17px;height:1px;background:currentColor;transform:scaleX(0);transform-origin:left;transition:transform .25s var(--ease)}.ah-primary a:hover,.ah-primary a.on{color:var(--world-ink)}.ah-primary a.on::after{transform:scaleX(1)}
.ah--movement .ah-primary a{color:var(--world-nav-faint)}.ah--movement .ah-primary a:hover,.ah--movement .ah-primary a.on{color:var(--world-nav-ink)}

.ah-actions{justify-self:end;display:flex;align-items:center;gap:9px;min-width:0}.ah-signin{display:inline-flex;align-items:center;justify-content:center;min-height:38px;padding:0 16px;border:1px solid var(--world-line-strong);border-radius:999px;color:var(--world-ink);background:color-mix(in srgb,var(--world-surface) 60%,transparent);font:600 11px/1 var(--font-display);text-decoration:none;transition:.2s}.ah-signin:hover{background:var(--world-ink);border-color:var(--world-ink);color:var(--world-canvas)}.ah--movement .ah-signin{border-color:var(--world-nav-line);color:var(--world-nav-ink);background:rgba(255,255,255,.035)}.ah--movement .ah-signin:hover{background:var(--world-nav-ink);color:var(--world-nav)}
.ah-explore{display:none;align-items:center;gap:7px;min-height:40px;padding:0 12px;background:none;border:1px solid var(--world-line);border-radius:999px;color:inherit;font:600 11px/1 var(--font-display);cursor:pointer}.ah-explore span{font-size:12px}

.ah-account{position:relative}.ah-chip{display:flex;align-items:center;gap:9px;min-height:42px;padding:4px 11px 4px 4px;border-radius:999px;background:color-mix(in srgb,var(--world-surface) 56%,transparent);border:1px solid var(--world-line);cursor:pointer;color:inherit;font-family:inherit;transition:.2s}.ah-chip:hover{background:var(--world-surface)}.ah--movement .ah-chip{background:rgba(255,255,255,.035);border-color:var(--world-nav-line)}.ah--movement .ah-chip:hover{background:rgba(255,255,255,.07)}
.ah-chip-id{display:flex;flex-direction:column;align-items:flex-start;line-height:1.08}.ah-chip-name{max-width:120px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:11.5px;font-weight:650;color:inherit}.ah-chip-role{margin-top:2px;font:600 8px/1 var(--font-mono);text-transform:uppercase;letter-spacing:.06em;color:var(--world-ink-faint)}.ah-chip-caret{color:var(--world-ink-faint);font-size:11px}
.ah-admin-tag{display:inline-flex;align-items:center;gap:3px;padding:2px 6px;border-radius:999px;background:var(--en-gold);color:#fff;font-size:8px;font-weight:800}.ah-chip-admin{box-shadow:inset 0 0 0 1px color-mix(in srgb,var(--en-gold) 55%,transparent)}

.ah-menu,.ah-mobile-nav{background:color-mix(in srgb,var(--world-surface) 96%,transparent);border:1px solid var(--world-line-strong);box-shadow:var(--shadow-lg);backdrop-filter:blur(20px)}.ah-menu{position:absolute;top:calc(100% + 10px);right:0;width:270px;border-radius:18px;padding:10px;z-index:90}.ah-menu-handle{display:none;width:38px;height:3px;margin:0 auto 8px;border-radius:999px;background:var(--world-line-strong)}.ah-menu-head{display:flex;align-items:center;gap:11px;padding:10px 10px 13px;border-bottom:1px solid var(--world-line);margin-bottom:6px}.ah-menu-name{font-weight:700;font-size:13px;color:var(--world-ink)}.ah-menu-role{margin-top:2px;font-size:10px;color:var(--world-ink-faint);overflow:hidden;text-overflow:ellipsis;max-width:180px;white-space:nowrap}.ah-menu-spaces-l{font:600 9px/1 var(--font-mono);text-transform:uppercase;letter-spacing:.09em;color:var(--world-ink-faint);padding:7px 11px}.ah-menu-item{display:flex;align-items:center;gap:10px;width:100%;min-height:42px;padding:9px 11px;border-radius:11px;font-size:12px;font-weight:550;color:var(--world-ink-soft);background:none;border:0;font-family:inherit;text-align:left;cursor:pointer;text-decoration:none;position:relative}.ah-menu-item:hover{background:var(--world-surface-2);color:var(--world-ink)}.ah-menu-item.danger{color:var(--owed-ink)}.ah-menu-sep{height:1px;background:var(--world-line);margin:6px 4px}.ah-space.cur{background:var(--world-accent-soft);color:var(--world-accent-ink)}.ah-cur-dot{position:absolute;right:13px;width:6px;height:6px;border-radius:50%;background:var(--world-accent)}.ah-admin-tag-menu{margin-left:7px}

.ah-mobile-nav{display:none;position:fixed;z-index:88;left:12px;right:12px;bottom:calc(12px + env(safe-area-inset-bottom));padding:14px 10px 10px;border-radius:20px}.ah-mobile-label{padding:5px 12px 10px;font:600 9px/1 var(--font-mono);text-transform:uppercase;letter-spacing:.1em;color:var(--world-ink-faint)}.ah-mobile-nav a{display:flex;align-items:center;justify-content:space-between;min-height:52px;padding:11px 12px;border-radius:12px;border-bottom:1px solid var(--world-line);font:600 15px/1 var(--font-display);color:var(--world-ink);text-decoration:none}.ah-mobile-nav a:last-child{border-bottom:0}.ah-mobile-nav a.on{color:var(--world-accent-ink);background:var(--world-accent-soft)}
.ah-menu-enter-active,.ah-menu-leave-active{transition:opacity .18s var(--ease),transform .18s var(--ease)}.ah-menu-enter-from,.ah-menu-leave-to{opacity:0;transform:translateY(-5px)}

@media(max-width:980px){.ah-inner{grid-template-columns:1fr auto;min-height:66px}.ah-primary{display:none}.ah-explore{display:inline-flex}.ah-context-copy small{display:none}}
@media(max-width:640px){
  .ah{padding-top:env(safe-area-inset-top)}.ah-inner{width:calc(100% - 28px);min-height:60px;gap:8px}.ah-brand{gap:9px;max-width:calc(100vw - 170px)}.ah-brand :deep(.brandmark){max-width:116px}.ah-context{gap:8px}.ah-context-line{height:22px}.ah-context-copy strong{font-size:10.5px;max-width:78px}.ah-live{display:none}
  .ah-actions{gap:6px}.ah-explore{min-width:42px;width:42px;padding:0;justify-content:center;font-size:0}.ah-explore::before{content:"•••";font-size:11px;letter-spacing:2px;line-height:1}.ah-explore span{display:none}.ah-signin{min-height:40px;padding:0 13px}.ah-chip{width:42px;height:42px;padding:4px;justify-content:center}.ah-chip-id,.ah-chip-caret{display:none}
  .ah-menu{position:fixed;left:12px;right:12px;top:auto;bottom:calc(12px + env(safe-area-inset-bottom));width:auto;max-height:min(72dvh,580px);overflow:auto;border-radius:20px;padding:14px 10px 10px;overscroll-behavior:contain}.ah-menu-handle{display:block}.ah-menu-head{padding:10px 12px 14px}.ah-menu-item{min-height:48px;padding:11px 12px}
  .ah-mobile-nav{display:block}.ah-mobile-nav .ah-menu-handle{display:block}
}
</style>
