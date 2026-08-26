<script setup>
// The front door — for first-time visitors. Leads with trust + the promise,
// shows what you can do, proves how trust works, routes each audience in.
import { useRouter } from 'vue-router'
import BrandMark from '../components/BrandMark.vue'
import Icon from '../components/Icon.vue'
const router = useRouter()
</script>

<template>
<div class="ld">
  <!-- top bar: brand + demoted sign-in -->
  <header class="ld-nav">
    <div class="ld-nav-in">
      <BrandMark variant="full" :height="30" />
      <div class="ld-nav-r">
        <RouterLink to="/market" class="ld-nav-link">Marketplace</RouterLink>
        <RouterLink to="/track" class="ld-nav-link">Track a parcel</RouterLink>
        <RouterLink to="/login" class="ld-signin">Sign in</RouterLink>
      </div>
    </div>
  </header>

  <!-- HERO: promise, not login -->
  <section class="ld-hero">
    <div class="ld-hero-in">
      <div class="ld-eyebrow"><span class="ld-dot"></span> Tanzania's trusted delivery &amp; commerce network</div>
      <h1 class="ld-h1">Buy, sell, and send across Tanzania —<br><span class="ld-grad">and actually trust it arrives.</span></h1>
      <p class="ld-lede">Every parcel tracked end to end. Every shop delivered. Every plot verified. One platform where movement, money, and ownership are all accounted for — so you never have to just hope.</p>
      <div class="ld-cta">
        <RouterLink to="/market" class="ld-btn ld-btn-primary"><Icon name="box" :size="17" /> Explore the marketplace</RouterLink>
        <RouterLink to="/track" class="ld-btn ld-btn-ghost"><Icon name="pin" :size="16" /> Track a parcel</RouterLink>
      </div>
      <div class="ld-trustline"><Icon name="shield" :size="15" /> No account needed to track or browse · Cash on delivery · Every step recorded</div>
    </div>
    <div class="ld-hero-visual">
      <div class="ld-track-card">
        <div class="ld-tc-head"><span class="ld-tc-code">ENK-2918</span><span class="ld-tc-live"><span class="ld-tc-dot"></span> On the road</span></div>
        <div class="ld-tc-steps">
          <div class="ld-tc-step done"><span class="ld-tc-ic"><Icon name="check" :size="12" /></span> Booked · Amina's shop</div>
          <div class="ld-tc-step done"><span class="ld-tc-ic"><Icon name="check" :size="12" /></span> Collected · carrier verified</div>
          <div class="ld-tc-step done"><span class="ld-tc-ic"><Icon name="check" :size="12" /></span> On road · Dar → Mbeya</div>
          <div class="ld-tc-step now"><span class="ld-tc-ic"><Icon name="bike" :size="12" /></span> With driver · Charles</div>
          <div class="ld-tc-step"><span class="ld-tc-ic"></span> Delivered · proof + signature</div>
        </div>
      </div>
    </div>
  </section>

  <!-- WHAT YOU CAN DO: three concrete doors -->
  <section class="ld-section">
    <div class="ld-sec-head"><h2>Everything in one trusted place</h2><p>Three things you can do today — each one tracked, verified, and accounted for.</p></div>
    <div class="ld-cards">
      <RouterLink to="/track" class="ld-card">
        <div class="ld-card-ic"><Icon name="route" :size="22" /></div>
        <h3>Send &amp; receive, tracked</h3>
        <p>Book a delivery or follow one coming to you — see every step live, with proof at handover and cash reconciled.</p>
        <span class="ld-card-go">Track a parcel <Icon name="arrow" :size="14" /></span>
      </RouterLink>
      <RouterLink to="/market" class="ld-card">
        <div class="ld-card-ic"><Icon name="box" :size="22" /></div>
        <h3>Shop, delivered</h3>
        <p>Buy from Tanzanian businesses with delivery built in — order, pay on delivery, and track it the whole way.</p>
        <span class="ld-card-go">Browse the marketplace <Icon name="arrow" :size="14" /></span>
      </RouterLink>
      <RouterLink to="/property" class="ld-card">
        <div class="ld-card-ic"><Icon name="pin" :size="22" /></div>
        <h3>Buy verified land</h3>
        <p>Browse plots, farms and houses that our team reviews before they're listed — no ghost listings, no guesswork.</p>
        <span class="ld-card-go">See verified property <Icon name="arrow" :size="14" /></span>
      </RouterLink>
    </div>
  </section>

  <!-- WHY ENKIAMA: the trust proof -->
  <section class="ld-why">
    <div class="ld-why-in">
      <div class="ld-sec-head light"><h2>Why people trust Enkiama</h2><p>Trust isn't a slogan here — it's built into how everything works.</p></div>
      <div class="ld-proof">
        <div class="ld-proof-item"><span class="ld-proof-ic"><Icon name="shield" :size="18" /></span><div><b>A custody ledger, not a promise</b><span>Every hand that touches a parcel is recorded — booked, collected, on road, delivered.</span></div></div>
        <div class="ld-proof-item"><span class="ld-proof-ic"><Icon name="camera" :size="18" /></span><div><b>Proof on delivery</b><span>Photo and timestamp at handover, so "it was delivered" is a fact, not a claim.</span></div></div>
        <div class="ld-proof-item"><span class="ld-proof-ic"><Icon name="cash" :size="18" /></span><div><b>Cash reconciled</b><span>Cash-on-delivery is collected and remitted through the platform — no disputes over money.</span></div></div>
        <div class="ld-proof-item"><span class="ld-proof-ic"><Icon name="check" :size="18" /></span><div><b>Verified sellers &amp; listings</b><span>Drivers are ID-checked by their carrier; property is reviewed before it's shown.</span></div></div>
      </div>
    </div>
  </section>

  <!-- HOW IT WORKS -->
  <section class="ld-section">
    <div class="ld-sec-head"><h2>How it works</h2></div>
    <div class="ld-steps">
      <div class="ld-step"><span class="ld-step-n">1</span><b>Order or send</b><p>Buy from a shop, or book a parcel with a tracked carrier.</p></div>
      <div class="ld-step"><span class="ld-step-n">2</span><b>Follow every step</b><p>Watch it move — booked, collected, on the road, with your driver.</p></div>
      <div class="ld-step"><span class="ld-step-n">3</span><b>Delivered with proof</b><p>Photo, signature, and cash reconciled. One parcel, one truth.</p></div>
    </div>
  </section>

  <!-- PER-AUDIENCE CTAs -->
  <section class="ld-join">
    <div class="ld-join-in">
      <h2>Ready to build with us?</h2>
      <div class="ld-join-grid">
        <RouterLink to="/join/business" class="ld-join-card"><Icon name="building" :size="20" /><b>Run a business</b><span>Sell with delivery built in</span></RouterLink>
        <RouterLink to="/driver/apply" class="ld-join-card"><Icon name="bike" :size="20" /><b>Drive</b><span>Join a carrier, start earning</span></RouterLink>
        <RouterLink to="/join/carrier" class="ld-join-card"><Icon name="route" :size="20" /><b>Operate a fleet</b><span>Run your carrier on one system</span></RouterLink>
        <RouterLink to="/property" class="ld-join-card"><Icon name="pin" :size="20" /><b>List property</b><span>Reach verified buyers</span></RouterLink>
      </div>
    </div>
  </section>

  <footer class="ld-foot">
    <div class="ld-foot-in">
      <BrandMark variant="full" :height="26" />
      <div class="ld-foot-tag">One parcel, one truth · Tanzania</div>
      <div class="ld-foot-links">
        <RouterLink to="/market">Marketplace</RouterLink>
        <RouterLink to="/property">Property</RouterLink>
        <RouterLink to="/track">Track</RouterLink>
        <RouterLink to="/login">Sign in</RouterLink>
      </div>
    </div>
  </footer>
</div>
</template>

<style scoped>
.ld{background:var(--paper)}
.ld-nav{position:sticky;top:0;z-index:50;background:rgba(20,24,31,.9);backdrop-filter:blur(10px);border-bottom:1px solid rgba(255,255,255,.06)}
.ld-nav-in{max-width:1140px;margin:0 auto;padding:14px 24px;display:flex;align-items:center;justify-content:space-between}
.ld-nav-in :deep(svg){filter:brightness(0) invert(1)}
.ld-nav-r{display:flex;align-items:center;gap:8px}
.ld-nav-link{color:rgba(255,255,255,.8);font-size:14px;font-weight:600;padding:8px 14px;border-radius:9px;text-decoration:none;transition:.15s}
.ld-nav-link:hover{background:rgba(255,255,255,.08);color:#fff}
.ld-signin{color:#fff;font-size:14px;font-weight:600;padding:8px 18px;border-radius:9px;border:1px solid rgba(255,255,255,.2);text-decoration:none;transition:.15s}
.ld-signin:hover{background:#fff;color:var(--ink)}

/* HERO */
.ld-hero{background:linear-gradient(165deg,var(--ink),#141C24 55%,#0B3A32);color:#fff;position:relative;overflow:hidden}
.ld-hero::before{content:'';position:absolute;inset:0;background:radial-gradient(700px 400px at 78% 8%,rgba(79,209,181,.16),transparent 60%);pointer-events:none}
.ld-hero-in{max-width:1140px;margin:0 auto;padding:70px 24px 60px;position:relative;z-index:1;max-width:640px;margin-left:max(24px,calc((100vw - 1140px)/2 + 24px))}
.ld-eyebrow{display:inline-flex;align-items:center;gap:8px;font-size:12.5px;font-weight:700;text-transform:uppercase;letter-spacing:.05em;color:rgba(255,255,255,.82);margin-bottom:22px;background:rgba(255,255,255,.06);border:1px solid rgba(255,255,255,.1);padding:7px 14px;border-radius:999px}
.ld-dot{width:7px;height:7px;border-radius:50%;background:#4FD1B5;box-shadow:0 0 0 4px rgba(79,209,181,.2)}
.ld-h1{font-family:'Space Grotesk',sans-serif;font-size:clamp(32px,5vw,54px);font-weight:700;letter-spacing:-.035em;line-height:1.05;margin-bottom:20px;color:#fff}
.ld-grad{background:linear-gradient(110deg,#4FD1B5,#7EE8CF);-webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent}
.ld-lede{font-size:17px;line-height:1.6;color:rgba(255,255,255,.75);max-width:540px;margin-bottom:30px}
.ld-cta{display:flex;gap:12px;flex-wrap:wrap;margin-bottom:22px}
.ld-btn{display:inline-flex;align-items:center;gap:8px;padding:14px 24px;border-radius:12px;font-size:15px;font-weight:650;text-decoration:none;transition:.18s}
.ld-btn-primary{background:linear-gradient(135deg,#12B886,#0B6E5D);color:#fff;box-shadow:0 8px 24px rgba(11,110,93,.4)}
.ld-btn-primary:hover{transform:translateY(-2px);box-shadow:0 12px 30px rgba(11,110,93,.5)}
.ld-btn-ghost{background:rgba(255,255,255,.08);color:#fff;border:1px solid rgba(255,255,255,.16)}
.ld-btn-ghost:hover{background:rgba(255,255,255,.14)}
.ld-trustline{display:flex;align-items:center;gap:8px;font-size:13px;color:rgba(255,255,255,.6)}
.ld-trustline svg{color:#4FD1B5}
/* hero visual */
.ld-hero-visual{position:absolute;right:calc((100vw - 1140px)/2 + 24px);top:50%;transform:translateY(-50%);z-index:1;width:340px}
.ld-track-card{background:rgba(255,255,255,.07);border:1px solid rgba(255,255,255,.12);border-radius:18px;padding:22px;backdrop-filter:blur(12px);box-shadow:0 24px 60px rgba(0,0,0,.4)}
.ld-tc-head{display:flex;align-items:center;justify-content:space-between;margin-bottom:18px}
.ld-tc-code{font-family:'Spline Sans Mono',monospace;font-size:15px;font-weight:600;color:#fff;letter-spacing:.02em}
.ld-tc-live{display:inline-flex;align-items:center;gap:6px;font-size:12px;font-weight:600;color:#4FD1B5}
.ld-tc-dot{width:7px;height:7px;border-radius:50%;background:#4FD1B5;animation:ldpulse 2s infinite}
@keyframes ldpulse{0%,100%{opacity:1}50%{opacity:.4}}
.ld-tc-steps{display:flex;flex-direction:column;gap:14px}
.ld-tc-step{display:flex;align-items:center;gap:11px;font-size:13.5px;color:rgba(255,255,255,.4)}
.ld-tc-step.done{color:rgba(255,255,255,.75)}
.ld-tc-step.now{color:#fff;font-weight:600}
.ld-tc-ic{width:22px;height:22px;border-radius:50%;border:1.5px solid rgba(255,255,255,.15);display:flex;align-items:center;justify-content:center;flex-shrink:0}
.ld-tc-step.done .ld-tc-ic{background:#12B886;border-color:#12B886;color:#fff}
.ld-tc-step.now .ld-tc-ic{background:#4FD1B5;border-color:#4FD1B5;color:var(--ink)}
@media(max-width:1000px){.ld-hero-visual{display:none}.ld-hero-in{max-width:640px;margin:0 auto}}

/* SECTIONS */
.ld-section{max-width:1140px;margin:0 auto;padding:72px 24px}
.ld-sec-head{text-align:center;margin-bottom:42px}
.ld-sec-head h2{font-family:'Space Grotesk',sans-serif;font-size:clamp(26px,3.4vw,36px);font-weight:700;letter-spacing:-.03em;color:var(--ink);margin-bottom:10px}
.ld-sec-head p{font-size:16px;color:var(--ink-soft);max-width:520px;margin:0 auto}
.ld-sec-head.light h2{color:#fff}
.ld-sec-head.light p{color:rgba(255,255,255,.65)}
.ld-cards{display:grid;grid-template-columns:repeat(3,1fr);gap:20px}
.ld-card{display:flex;flex-direction:column;background:var(--surface);border:1px solid var(--hairline);border-radius:16px;padding:26px;text-decoration:none;box-shadow:var(--shadow-sm);transition:transform var(--dur) var(--ease),box-shadow var(--dur) var(--ease)}
.ld-card:hover{transform:translateY(-4px);box-shadow:var(--shadow-md)}
.ld-card-ic{width:52px;height:52px;border-radius:14px;background:var(--accent-soft);color:var(--accent-ink);display:flex;align-items:center;justify-content:center;margin-bottom:16px}
.ld-card h3{font-family:'Space Grotesk',sans-serif;font-size:19px;font-weight:700;letter-spacing:-.02em;color:var(--ink);margin-bottom:8px}
.ld-card p{font-size:14px;line-height:1.6;color:var(--ink-soft);flex:1;margin-bottom:16px}
.ld-card-go{display:inline-flex;align-items:center;gap:6px;font-size:14px;font-weight:650;color:var(--accent-ink)}

/* WHY */
.ld-why{background:linear-gradient(165deg,#141C24,var(--ink));color:#fff}
.ld-why-in{max-width:1140px;margin:0 auto;padding:72px 24px}
.ld-proof{display:grid;grid-template-columns:1fr 1fr;gap:22px;max-width:860px;margin:0 auto}
.ld-proof-item{display:flex;gap:14px;align-items:flex-start}
.ld-proof-ic{width:44px;height:44px;border-radius:12px;background:rgba(79,209,181,.14);color:#4FD1B5;display:flex;align-items:center;justify-content:center;flex-shrink:0}
.ld-proof-item b{display:block;font-size:16px;font-weight:650;margin-bottom:4px}
.ld-proof-item span{font-size:14px;line-height:1.55;color:rgba(255,255,255,.65)}

/* STEPS */
.ld-steps{display:grid;grid-template-columns:repeat(3,1fr);gap:24px;max-width:900px;margin:0 auto}
.ld-step{text-align:center}
.ld-step-n{display:inline-flex;align-items:center;justify-content:center;width:44px;height:44px;border-radius:50%;background:var(--accent);color:#fff;font-family:'Space Grotesk',sans-serif;font-weight:700;font-size:18px;margin-bottom:14px}
.ld-step b{display:block;font-size:17px;font-weight:700;color:var(--ink);margin-bottom:6px;font-family:'Space Grotesk',sans-serif}
.ld-step p{font-size:14px;color:var(--ink-soft);line-height:1.55}

/* JOIN */
.ld-join{background:var(--surface-2);border-top:1px solid var(--hairline)}
.ld-join-in{max-width:1140px;margin:0 auto;padding:64px 24px;text-align:center}
.ld-join-in h2{font-family:'Space Grotesk',sans-serif;font-size:clamp(24px,3vw,32px);font-weight:700;letter-spacing:-.03em;color:var(--ink);margin-bottom:32px}
.ld-join-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:16px}
.ld-join-card{display:flex;flex-direction:column;align-items:center;gap:6px;background:var(--surface);border:1px solid var(--hairline);border-radius:14px;padding:24px 16px;text-decoration:none;transition:.18s;color:var(--accent-ink)}
.ld-join-card:hover{transform:translateY(-3px);box-shadow:var(--shadow-md);border-color:var(--accent)}
.ld-join-card b{font-size:15px;color:var(--ink);margin-top:6px}
.ld-join-card span{font-size:12.5px;color:var(--ink-faint)}

/* FOOTER */
.ld-foot{background:var(--ink);color:#fff}
.ld-foot-in{max-width:1140px;margin:0 auto;padding:36px 24px;display:flex;align-items:center;gap:20px;flex-wrap:wrap}
.ld-foot-in :deep(svg){filter:brightness(0) invert(1)}
.ld-foot-tag{font-size:13px;color:rgba(255,255,255,.5)}
.ld-foot-links{margin-left:auto;display:flex;gap:20px}
.ld-foot-links a{font-size:13.5px;color:rgba(255,255,255,.7);text-decoration:none}
.ld-foot-links a:hover{color:#fff}

@media(max-width:820px){
  .ld-cards,.ld-proof,.ld-steps,.ld-join-grid{grid-template-columns:1fr}
  .ld-nav-link{display:none}
}
</style>
