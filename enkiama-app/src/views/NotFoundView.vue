<script setup>
import AppHeader from '../components/AppHeader.vue'
import SiteFooter from '../components/SiteFooter.vue'
import ExperienceState from '../components/ExperienceState.vue'
</script>

<template>
  <div class="nf-page">
    <AppHeader title="Enkiama" />
    <main id="main-content" class="nf-main">
      <ExperienceState
        world="market"
        kind="unavailable"
        eyebrow="404 · Route"
        title="This route does not lead anywhere."
        body="The address may be incomplete, outdated or mistyped. Your account and marketplace data have not been changed."
      >
        <RouterLink to="/market">Open Market</RouterLink>
        <RouterLink to="/track">Track a parcel</RouterLink>
        <RouterLink to="/">Enkiama home</RouterLink>
      </ExperienceState>
    </main>
    <SiteFooter />
  </div>
</template>

<style scoped>
.nf-page{min-height:100svh;background:var(--world-canvas);color:var(--world-ink)}
.nf-main{width:min(1180px,calc(100% - 48px));margin:0 auto;padding:clamp(48px,8vw,104px) 0 clamp(72px,10vw,128px)}
@media(max-width:640px){.nf-main{width:calc(100% - 28px);padding-top:42px}}
</style>
