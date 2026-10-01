<script setup>
import Icon from './Icon.vue'

const props = defineProps({
  kind: { type:String, default:'empty' },
  world: { type:String, default:'market' },
  eyebrow: { type:String, default:'' },
  title: { type:String, default:'' },
  body: { type:String, default:'' },
  icon: { type:String, default:'' },
  compact: { type:Boolean, default:false },
})

const fallbackIcon = {
  loading:'clock', empty:'inbox', error:'alert', unavailable:'package', offline:'alert'
}
</script>

<template>
  <section class="xs" :class="[`xs-${kind}`, `xs-${world}`, {compact}]" :aria-live="kind==='loading' ? 'polite' : 'assertive'">
    <div class="xs-scene" aria-hidden="true">
      <div class="xs-plane one"></div><div class="xs-plane two"></div><div class="xs-plane three"></div>
      <div class="xs-signal"><i></i><i></i><i></i></div>
    </div>
    <div class="xs-copy">
      <span class="xs-eyebrow">{{ eyebrow || (kind === 'loading' ? 'Loading' : kind === 'error' ? 'Connection' : kind === 'unavailable' ? 'Availability' : 'Enkiama') }}</span>
      <div class="xs-icon"><Icon :name="icon || fallbackIcon[kind] || 'inbox'" :size="18" /></div>
      <h2>{{ title }}</h2>
      <p v-if="body">{{ body }}</p>
      <div class="xs-actions"><slot /></div>
    </div>
  </section>
</template>

<style scoped>
.xs{--xs-bg:#f3eee4;--xs-ink:#18231d;--xs-line:rgba(24,35,29,.16);--xs-accent:#466a55;display:grid;grid-template-columns:minmax(240px,.78fr) minmax(0,1.22fr);min-height:300px;border-top:1px solid var(--xs-line);border-bottom:1px solid var(--xs-line);background:var(--xs-bg);overflow:hidden}
.xs-object{--xs-bg:#f4f3ee;--xs-accent:#6d765f}.xs-place{--xs-bg:#e9e2d6;--xs-accent:#536753}.xs-business{--xs-bg:#efe5d7;--xs-accent:#856a4e}.xs-movement{--xs-bg:#e9efeb;--xs-accent:#2f704f}.xs-error{--xs-accent:#8b5147}.xs-unavailable{--xs-accent:#77776f}
.xs-scene{position:relative;min-height:300px;background:linear-gradient(145deg,color-mix(in srgb,var(--xs-bg) 82%,#fff),var(--xs-bg));overflow:hidden}.xs-plane{position:absolute;border:1px solid color-mix(in srgb,var(--xs-accent) 24%,transparent);border-radius:50%}.xs-plane.one{width:330px;height:330px;left:-90px;top:-95px;box-shadow:0 0 0 28px color-mix(in srgb,var(--xs-accent) 4%,transparent),0 0 0 64px color-mix(in srgb,var(--xs-accent) 2.5%,transparent)}.xs-plane.two{width:220px;height:120px;right:-40px;bottom:20px;transform:rotate(-18deg)}.xs-plane.three{width:170px;height:70px;left:30%;top:48%;transform:rotate(14deg)}
.xs-signal{position:absolute;left:18%;right:15%;top:54%;height:1px;background:color-mix(in srgb,var(--xs-accent) 32%,transparent);transform:rotate(-10deg)}.xs-signal i{position:absolute;top:-4px;width:8px;height:8px;border-radius:50%;background:var(--xs-accent);box-shadow:0 0 0 7px color-mix(in srgb,var(--xs-accent) 10%,transparent)}.xs-signal i:nth-child(1){left:0}.xs-signal i:nth-child(2){left:48%}.xs-signal i:nth-child(3){right:0}
.xs-copy{padding:48px clamp(28px,5vw,70px);display:flex;flex-direction:column;justify-content:center;align-items:flex-start}.xs-eyebrow{font:700 9px/1 'Inter',sans-serif;text-transform:uppercase;letter-spacing:.16em;color:color-mix(in srgb,var(--xs-ink) 48%,transparent)}.xs-icon{width:34px;height:34px;border:1px solid var(--xs-line);display:grid;place-items:center;margin:20px 0 18px;color:var(--xs-accent);background:color-mix(in srgb,var(--xs-bg) 70%,#fff)}.xs h2{font:520 clamp(28px,4vw,50px)/1 'Space Grotesk',sans-serif;letter-spacing:-.05em;color:var(--xs-ink);margin:0;max-width:720px}.xs p{max-width:620px;font:400 12.5px/1.7 'Inter',sans-serif;color:color-mix(in srgb,var(--xs-ink) 62%,transparent);margin:16px 0 0}.xs-actions{display:flex;gap:20px;flex-wrap:wrap;margin-top:25px}.xs-actions:empty{display:none}.xs-actions :deep(a),.xs-actions :deep(button){border:0;border-bottom:1px solid color-mix(in srgb,var(--xs-ink) 35%,transparent);background:transparent;color:var(--xs-ink);font:700 10.5px/1.3 'Inter',sans-serif;padding:0 0 6px;text-decoration:none;cursor:pointer}
.xs.compact{grid-template-columns:120px 1fr;min-height:180px}.xs.compact .xs-scene{min-height:180px}.xs.compact .xs-copy{padding:26px 28px}.xs.compact h2{font-size:26px}.xs.compact p{margin-top:10px}.xs.compact .xs-icon{display:none}
@media(max-width:700px){.xs{grid-template-columns:1fr}.xs-scene{min-height:180px}.xs-copy{padding:30px 22px 36px}.xs h2{font-size:34px}.xs.compact{grid-template-columns:1fr}.xs.compact .xs-scene{display:none}}
@media(prefers-reduced-motion:reduce){.xs *{animation:none!important;transition:none!important}}
</style>
