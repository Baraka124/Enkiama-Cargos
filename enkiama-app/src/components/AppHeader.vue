<script setup>
// Unified app shell header — one consistent bar for every screen.
// Auth-aware: shows a clean visitor state OR a logged-in identity chip + account menu.
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import BrandMark from './BrandMark.vue'
import CarrierMark from './CarrierMark.vue'
import Avatar from './Avatar.vue'
import Icon from './Icon.vue'
import { useAuth } from '../composables/useAuth'
import { supabase } from '../lib/supabase'

const props = defineProps({
  title: { type: String, default: 'Enkiama Cargos' },
  subtitle: { type: String, default: '' },
  carrier: { type: Object, default: null },
  live: { type: Boolean, default: false },
  market: { type: Boolean, default: true },
})

const router = useRouter()
const { session, profile, signOut, isPlatformAdmin } = useAuth()
const menuOpen = ref(false)

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

async function doSignOut() { menuOpen.value = false; await signOut(); router.push('/login') }

// surface the person's OTHER space (their shop) so multi-hat identity is legible
const myShop = ref(null)
onMounted(async () => {
  if (!session?.value?.user?.id) return
  try {
    const { data } = await supabase.from('storefront').select('slug,name').eq('owner_id', session.value.user.id).maybeSingle()
    myShop.value = data || null
  } catch (e) {}
})
function isCurrent(path) { return router.currentRoute.value.path === path }
</script>

<template>
  <header class="ah">
    <div class="ah-inner">
      <div class="ah-brand" @click="router.push(isLoggedIn ? homePath : '/')" role="button">
        <CarrierMark v-if="carrier" :slug="carrier.slug" :mark="carrier.mark" :name="carrier.name" :accent="carrier.accent" :size="38" />
        <BrandMark v-else variant="mark" :height="34" light />
        <div class="ah-id">
          <div class="ah-title">{{ title }}</div>
          <div v-if="subtitle" class="ah-sub">{{ subtitle }}</div>
        </div>
        <span v-if="live" class="ah-live"><span class="ah-live-dot"></span>Live</span>
      </div>

      <div class="ah-actions">
        <RouterLink v-if="market" to="/market" class="ah-navlink"><Icon name="box" :size="15" /> <span class="ah-hide-sm">Marketplace</span></RouterLink>
        <slot />

        <!-- VISITOR: clear sign-in -->
        <RouterLink v-if="!isLoggedIn" to="/login" class="btn btn-accent ah-signin">Sign in</RouterLink>

        <!-- LOGGED-IN: identity chip + account menu -->
        <div v-else class="ah-account">
          <button class="ah-chip" :class="{'ah-chip-admin': isPlatformAdmin}" @click="menuOpen = !menuOpen" :aria-expanded="menuOpen">
            <Avatar :name="displayName" size="sm" />
            <span class="ah-chip-id">
              <span class="ah-chip-name">{{ displayName }}</span>
              <span v-if="isPlatformAdmin" class="ah-chip-role ah-admin-tag"><Icon name="shield" :size="10" /> Admin</span>
              <span v-else-if="roleLabel" class="ah-chip-role">{{ roleLabel }}</span>
            </span>
            <Icon name="arrow" :size="13" class="ah-chip-caret" />
          </button>
          <transition name="ah-menu">
            <div v-if="menuOpen" class="ah-menu" v-click-outside="() => menuOpen=false">
              <div class="ah-menu-head">
                <Avatar :name="displayName" />
                <div><div class="ah-menu-name">{{ displayName }}<span v-if="isPlatformAdmin" class="ah-admin-tag ah-admin-tag-menu"><Icon name="shield" :size="10" /> Admin</span></div><div class="ah-menu-role">{{ session?.user?.email }}</div></div>
              </div>
              <div class="ah-menu-spaces-l">You're in</div>
              <RouterLink :to="homePath" class="ah-menu-item ah-space" :class="{cur: isCurrent(homePath)}" @click="menuOpen=false">
                <Icon name="display" :size="15" /> <span>{{ roleLabel }} dashboard</span>
                <span v-if="isCurrent(homePath)" class="ah-cur-dot"></span>
              </RouterLink>
              <RouterLink v-if="myShop" :to="`/shop/${myShop.slug}`" class="ah-menu-item ah-space" @click="menuOpen=false">
                <Icon name="building" :size="15" /> <span>My shop · {{ myShop.name }}</span>
              </RouterLink>
              <div class="ah-menu-sep"></div>
              <RouterLink to="/account" class="ah-menu-item" @click="menuOpen=false"><Icon name="pen" :size="15" /> Edit profile</RouterLink>
              <RouterLink to="/market" class="ah-menu-item" @click="menuOpen=false"><Icon name="box" :size="15" /> Marketplace</RouterLink>
              <div class="ah-menu-sep"></div>
              <button class="ah-menu-item danger" @click="doSignOut"><Icon name="signout" :size="15" /> Sign out</button>
            </div>
          </transition>
        </div>
      </div>
    </div>
  </header>
</template>

<style scoped>
.ah{position:sticky;top:0;z-index:60;background:var(--nav);box-shadow:0 1px 0 var(--nav-line),var(--shadow-sm)}
.ah-inner{max-width:1180px;margin:0 auto;padding:var(--s3) var(--s6);display:flex;align-items:center;gap:var(--s4)}
.ah-brand{display:flex;align-items:center;gap:var(--s3);min-width:0;cursor:pointer}

.ah-id{min-width:0}
.ah-title{font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:var(--t-lg);color:var(--nav-ink);line-height:1.1;letter-spacing:-.02em;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.ah-sub{font-size:var(--t-xs);color:var(--nav-faint);text-transform:uppercase;letter-spacing:.03em;font-weight:500;margin-top:2px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.ah-live{display:inline-flex;align-items:center;gap:5px;font-size:var(--t-xs);font-weight:600;color:var(--go-ink);background:var(--go-soft);padding:4px 10px;border-radius:var(--r-full);margin-left:var(--s2)}
.ah-live-dot{width:6px;height:6px;border-radius:50%;background:var(--go);animation:ahPulse 2s var(--ease) infinite}
@keyframes ahPulse{0%,100%{opacity:1;transform:scale(1)}50%{opacity:.5;transform:scale(.8)}}
.ah-actions{margin-left:auto;display:flex;align-items:center;gap:var(--s2);flex-shrink:0}

.ah-navlink{display:inline-flex;align-items:center;gap:6px;padding:9px 14px;border-radius:10px;font-size:13px;font-weight:600;color:var(--nav-ink);background:var(--nav-soft);border:1px solid var(--nav-line);text-decoration:none;transition:.15s}
.ah-navlink:hover{background:#20262F;color:#fff}
.ah-signin{margin-left:2px}

/* identity chip */
.ah-account{position:relative}
.ah-chip{display:flex;align-items:center;gap:9px;padding:5px 10px 5px 5px;border-radius:12px;background:var(--nav-soft);border:1px solid var(--nav-line);cursor:pointer;transition:.15s;font-family:inherit}
.ah-chip:hover{background:#20262F;border-color:#333B49}
.ah-chip-id{display:flex;flex-direction:column;align-items:flex-start;line-height:1.15}
.ah-chip-name{font-size:13px;font-weight:650;color:#fff;max-width:130px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.ah-chip-role{font-size:11px;color:var(--nav-faint);text-transform:uppercase;letter-spacing:.03em;font-weight:600}
.ah-chip-caret{color:var(--nav-faint)}

/* account menu */
.ah-menu{position:absolute;top:calc(100% + 8px);right:0;width:250px;background:var(--surface);border:1px solid var(--hairline-2);border-radius:14px;box-shadow:var(--shadow-lg);padding:8px;z-index:70}
.ah-menu-head{display:flex;align-items:center;gap:11px;padding:10px 10px 12px;border-bottom:1px solid var(--hairline);margin-bottom:6px}
.ah-menu-name{font-weight:700;font-size:14px;color:var(--ink)}
.ah-menu-role{font-size:11px;color:var(--ink-faint);text-transform:uppercase;letter-spacing:.03em;font-weight:600}
.ah-menu-item{display:flex;align-items:center;gap:11px;width:100%;padding:10px 11px;border-radius:10px;font-size:13px;font-weight:550;color:var(--ink-soft);background:none;border:none;font-family:inherit;text-align:left;cursor:pointer;text-decoration:none;transition:.12s}
.ah-menu-item:hover{background:var(--surface-2);color:var(--ink)}
.ah-menu-item svg{color:var(--ink-faint);flex-shrink:0}
.ah-menu-item.danger{color:var(--owed-ink)}
.ah-menu-item.danger svg{color:var(--owed-ink)}
.ah-menu-item.danger:hover{background:var(--owed-soft)}
.ah-menu-sep{height:1px;background:var(--hairline);margin:6px 4px}
.ah-menu-enter-active,.ah-menu-leave-active{transition:opacity .16s var(--ease),transform .16s var(--ease)}
.ah-menu-enter-from,.ah-menu-leave-to{opacity:0;transform:translateY(-6px)}

@media(max-width:640px){
  .ah-inner{padding:var(--s3) var(--s4)}
  .ah-sub{display:none}
  .ah-hide-sm{display:none}
  .ah-chip-id{display:none}
  .ah-chip{padding:5px}
}

.ah-menu-spaces-l{font-size:10.5px;font-weight:700;text-transform:uppercase;letter-spacing:.05em;color:var(--ink-faint);padding:4px 11px 6px}
.ah-space{position:relative}
.ah-space.cur{background:var(--accent-soft)}
.ah-space.cur span{color:var(--accent-ink);font-weight:650}
.ah-cur-dot{position:absolute;right:12px;width:7px;height:7px;border-radius:50%;background:var(--accent);margin-left:auto}

.ah-admin-tag{display:inline-flex;align-items:center;gap:3px;background:linear-gradient(135deg,#C79A3E,#946B25);color:#fff;font-size:9.5px;font-weight:800;text-transform:uppercase;letter-spacing:.05em;padding:2px 7px;border-radius:6px}
.ah-chip-admin{box-shadow:inset 0 0 0 1.5px rgba(199,154,62,.5)}
.ah-admin-tag-menu{margin-left:8px;vertical-align:middle}
</style>
