<script setup>
import AppHeader from '../components/AppHeader.vue'
import SiteFooter from '../components/SiteFooter.vue'
import Icon from '../components/Icon.vue'
</script>

<template>
  <div class="home24">
    <AppHeader />

    <main>
      <!-- ARRIVAL -->
      <section class="home24-hero">
        <div class="home24-shell home24-hero-grid">
          <div class="home24-hero-copy" v-reveal="'copy'">
            <div class="home24-kicker">Enkiama · Tanzania</div>
            <h1>One system for<br><em>things that move</em><br>and things that stay.</h1>
            <p>
              Discover objects and businesses. Understand land before you act.
              Follow movement from hand to hand. Enkiama brings commerce,
              place and custody into one accountable experience.
            </p>

            <div class="home24-entry-actions">
              <RouterLink to="/market" class="home24-action home24-action-primary">
                Enter the Market <Icon name="arrow" :size="16" aria-hidden="true" />
              </RouterLink>
              <RouterLink to="/track" class="home24-action">
                Track a movement <Icon name="pin" :size="15" aria-hidden="true" />
              </RouterLink>
            </div>

            <div class="home24-hero-note">
              <span>Browse without an account</span>
              <span>Tracking stays public</span>
              <span>Transactions remain governed</span>
            </div>
          </div>

          <div class="home24-index" aria-label="Enkiama experience index" v-reveal="'media'">
            <RouterLink to="/market" class="home24-index-row home24-index-market">
              <span class="home24-index-no">01</span>
              <div>
                <small>Commerce</small>
                <strong>Market</strong>
                <p>Objects and Tanzanian businesses, with movement designed into the purchase.</p>
              </div>
              <Icon name="arrow" :size="18" aria-hidden="true" />
            </RouterLink>

            <RouterLink to="/property" class="home24-index-row home24-index-place">
              <span class="home24-index-no">02</span>
              <div>
                <small>Geography</small>
                <strong>Property</strong>
                <p>Places presented through location, ground, context, verification and terms.</p>
              </div>
              <Icon name="arrow" :size="18" aria-hidden="true" />
            </RouterLink>

            <RouterLink to="/track" class="home24-index-row home24-index-movement">
              <span class="home24-index-no">03</span>
              <div>
                <small>Custody</small>
                <strong>Movement</strong>
                <p>A recorded journey from sender to carrier to receiver, with proof where it matters.</p>
              </div>
              <Icon name="arrow" :size="18" aria-hidden="true" />
            </RouterLink>
          </div>
        </div>
      </section>

      <!-- THREE WORLDS -->
      <section class="home24-world home24-world-market">
        <div class="home24-shell home24-world-grid">
          <div class="home24-world-copy" v-reveal="'copy'">
            <span class="home24-world-number">01 / Market</span>
            <h2>Objects first.<br>Commerce second.</h2>
            <p>
              The Market is designed around what is actually being offered:
              the object, the business behind it, its price, and how it can reach you.
            </p>
            <RouterLink to="/market" class="home24-text-link">
              Explore the Market <Icon name="arrow" :size="15" aria-hidden="true" />
            </RouterLink>
          </div>

          <div class="home24-object-stage" aria-hidden="true" v-reveal="'media'">
            <div class="home24-object-plane home24-object-plane-a">
              <span>Object</span>
              <i></i>
            </div>
            <div class="home24-object-plane home24-object-plane-b">
              <span>Business</span>
              <i></i>
            </div>
            <div class="home24-object-ledger">
              <span>Offer</span><b>Clear</b>
              <span>Seller</span><b>Visible</b>
              <span>Movement</span><b>Connected</b>
            </div>
          </div>
        </div>
      </section>

      <section class="home24-world home24-world-place">
        <div class="home24-shell home24-world-grid home24-world-grid-reverse">
          <div class="home24-place-stage" aria-hidden="true" v-reveal="'media'">
            <div class="home24-place-gridlines"></div>
            <div class="home24-contours">
              <i></i><i></i><i></i><i></i><i></i>
            </div>
            <span class="home24-place-pin"></span>
            <div class="home24-place-caption">
              <span>Ground</span>
              <strong>Location before claim.</strong>
            </div>
          </div>

          <div class="home24-world-copy" v-reveal="'copy'">
            <span class="home24-world-number">02 / Property</span>
            <h2>See the place.<br>Understand the ground.</h2>
            <p>
              Property is treated as geography rather than a catalogue card:
              location, surroundings, verification and terms stay visible before commitment.
            </p>
            <RouterLink to="/property" class="home24-text-link">
              Explore Property <Icon name="arrow" :size="15" aria-hidden="true" />
            </RouterLink>
          </div>
        </div>
      </section>

      <section class="home24-world home24-world-movement">
        <div class="home24-shell home24-world-grid">
          <div class="home24-world-copy home24-world-copy-light" v-reveal="'copy'">
            <span class="home24-world-number">03 / Movement</span>
            <h2>Every handoff<br>changes the record.</h2>
            <p>
              Movement is not a decorative map. It is the custody story:
              who had it, what changed, where the journey stands, and what proof exists.
            </p>
            <RouterLink to="/track" class="home24-text-link home24-text-link-light">
              Track a parcel <Icon name="arrow" :size="15" aria-hidden="true" />
            </RouterLink>
          </div>

          <div class="home24-route-stage" aria-hidden="true" v-reveal="'media'">
            <div class="home24-route-head">
              <span>Sender</span><span>Carrier</span><span>You</span>
            </div>
            <div class="home24-route-line">
              <i class="home24-route-fill"></i>
              <b class="home24-route-node home24-route-node-a"></b>
              <b class="home24-route-node home24-route-node-b"></b>
              <b class="home24-route-node home24-route-node-c"></b>
            </div>
            <div class="home24-route-record">
              <span>Custody</span><strong>Recorded</strong>
              <span>Proof</span><strong>Attached</strong>
              <span>Status</span><strong>Current</strong>
            </div>
          </div>
        </div>
      </section>

      <!-- TRUST ARCHITECTURE -->
      <section class="home24-trust">
        <div class="home24-shell">
          <div class="home24-trust-head" v-reveal="'copy'">
            <span class="home24-kicker">The common layer</span>
            <h2>Trust is a structure,<br>not a badge.</h2>
            <p>
              Across commerce, property and logistics, Enkiama keeps the critical
              information attached to the decision instead of hiding it behind a promise.
            </p>
          </div>

          <div class="home24-trust-ledger" v-reveal="'line'">
            <div>
              <span>01</span>
              <strong>Identity</strong>
              <p>Know which business, carrier or party is attached to the record.</p>
            </div>
            <div>
              <span>02</span>
              <strong>Context</strong>
              <p>Price, place, route and terms remain visible before action.</p>
            </div>
            <div>
              <span>03</span>
              <strong>Custody</strong>
              <p>Movement is recorded as responsibility changes hands.</p>
            </div>
            <div>
              <span>04</span>
              <strong>Proof</strong>
              <p>Verification belongs close to the claim it supports.</p>
            </div>
          </div>
        </div>
      </section>

      <!-- PARTICIPATE -->
      <section class="home24-participate">
        <div class="home24-shell">
          <div class="home24-participate-head" v-reveal="'copy'">
            <span class="home24-kicker">Participate</span>
            <h2>Enter from where you are.</h2>
          </div>

          <div class="home24-participate-grid">
            <RouterLink to="/join/business" class="home24-participate-row">
              <span><Icon name="building" :size="18" aria-hidden="true" /> Business</span>
              <p>Sell through a storefront with movement built into the transaction.</p>
              <Icon name="arrow" :size="16" aria-hidden="true" />
            </RouterLink>

            <RouterLink to="/join/carrier" class="home24-participate-row">
              <span><Icon name="route" :size="18" aria-hidden="true" /> Carrier</span>
              <p>Operate a fleet through one custody and operations system.</p>
              <Icon name="arrow" :size="16" aria-hidden="true" />
            </RouterLink>

            <RouterLink to="/driver/apply" class="home24-participate-row">
              <span><Icon name="bike" :size="18" aria-hidden="true" /> Driver</span>
              <p>Join the movement network through a carrier-led workflow.</p>
              <Icon name="arrow" :size="16" aria-hidden="true" />
            </RouterLink>

            <RouterLink to="/property" class="home24-participate-row">
              <span><Icon name="pin" :size="18" aria-hidden="true" /> Property</span>
              <p>Explore the place system and the path to a governed listing.</p>
              <Icon name="arrow" :size="16" aria-hidden="true" />
            </RouterLink>
          </div>
        </div>
      </section>
    </main>

    <SiteFooter />
  </div>
</template>

<style scoped>
.home24{
  --h24-ink:#171a18;
  --h24-soft:#5f665f;
  --h24-line:rgba(23,26,24,.16);
  --h24-paper:#f2efe8;
  --h24-market:#eee8dc;
  --h24-object:#f7f4ed;
  --h24-place:#e8e1d4;
  --h24-movement:#0c1714;
  min-height:100svh;
  background:var(--h24-paper);
  color:var(--h24-ink);
}
.home24-shell{width:min(1380px,calc(100% - 96px));margin-inline:auto}
.home24-kicker,.home24-world-number{
  font:600 10px/1 var(--font-mono);
  letter-spacing:.13em;
  text-transform:uppercase;
}
.home24-kicker{color:#737a73}

/* ARRIVAL */
.home24-hero{padding:84px 0 96px;background:var(--h24-paper);border-bottom:1px solid var(--h24-line)}
.home24-hero-grid{display:grid;grid-template-columns:minmax(0,.92fr) minmax(500px,1.08fr);gap:9vw;align-items:end}
.home24-hero-copy{max-width:690px}
.home24-hero-copy h1{
  margin:22px 0 28px;
  font:500 clamp(56px,6.5vw,108px)/.88 var(--font-display);
  letter-spacing:-.07em;
  color:var(--h24-ink);
}
.home24-hero-copy h1 em{font-family:var(--font-editorial);font-weight:500;letter-spacing:-.045em}
.home24-hero-copy>p{max-width:590px;font-size:16px;line-height:1.75;color:var(--h24-soft)}
.home24-entry-actions{display:flex;align-items:center;gap:10px;margin-top:34px;flex-wrap:wrap}
.home24-action{
  min-height:48px;
  display:inline-flex;
  align-items:center;
  justify-content:space-between;
  gap:18px;
  padding:0 18px;
  border:1px solid var(--h24-line);
  border-radius:6px;
  color:var(--h24-ink);
  text-decoration:none;
  font-size:13px;
  font-weight:650;
}
.home24-action-primary{background:var(--h24-ink);border-color:var(--h24-ink);color:#f6f3ec}
.home24-action:hover{border-color:rgba(23,26,24,.42)}
.home24-action-primary:hover{background:#252a26}
.home24-hero-note{display:flex;gap:20px 28px;flex-wrap:wrap;margin-top:24px;padding-top:18px;border-top:1px solid var(--h24-line)}
.home24-hero-note span{font:500 10px/1.4 var(--font-mono);letter-spacing:.025em;color:#777d77}

.home24-index{border-top:1px solid var(--h24-line)}
.home24-index-row{
  min-height:158px;
  display:grid;
  grid-template-columns:42px minmax(0,1fr) 24px;
  gap:24px;
  align-items:start;
  padding:28px 0;
  border-bottom:1px solid var(--h24-line);
  color:var(--h24-ink);
  text-decoration:none;
  transition:padding .35s var(--ease),background .35s ease;
}
.home24-index-row:hover{padding-left:16px;padding-right:12px}
.home24-index-no{font:500 10px/1 var(--font-mono);color:#8b8f89;padding-top:7px}
.home24-index-row small{display:block;margin-bottom:8px;font:600 9px/1 var(--font-mono);letter-spacing:.13em;text-transform:uppercase;color:#7d827c}
.home24-index-row strong{display:block;font:500 30px/1 var(--font-display);letter-spacing:-.045em}
.home24-index-row p{max-width:520px;margin-top:10px;font-size:13px;line-height:1.6;color:#697069}
.home24-index-row>svg{margin-top:7px}
.home24-index-market:hover{background:color-mix(in srgb,var(--h24-market) 60%,transparent)}
.home24-index-place:hover{background:color-mix(in srgb,var(--h24-place) 54%,transparent)}
.home24-index-movement:hover{background:rgba(21,38,31,.055)}

/* WORLD CHAPTERS */
.home24-world{padding:126px 0}
.home24-world-grid{display:grid;grid-template-columns:minmax(0,.78fr) minmax(520px,1.22fr);gap:9vw;align-items:center}
.home24-world-grid-reverse{grid-template-columns:minmax(520px,1.22fr) minmax(0,.78fr)}
.home24-world-copy{max-width:520px}
.home24-world-number{display:block;margin-bottom:30px;color:#7a8079}
.home24-world-copy h2,.home24-trust-head h2,.home24-participate-head h2{
  margin:0;
  font:500 clamp(46px,5.1vw,78px)/.94 var(--font-display);
  letter-spacing:-.06em;
}
.home24-world-copy p{margin:26px 0 30px;max-width:500px;font-size:15px;line-height:1.76;color:#626961}
.home24-text-link{
  display:inline-flex;
  align-items:center;
  gap:10px;
  padding:10px 0;
  border-bottom:1px solid currentColor;
  color:var(--h24-ink);
  text-decoration:none;
  font-size:13px;
  font-weight:650;
}

.home24-world-market{background:var(--h24-market)}
.home24-object-stage{
  position:relative;
  min-height:570px;
  background:var(--h24-object);
  overflow:hidden;
  border:1px solid rgba(39,37,31,.1);
}
.home24-object-stage::before{
  content:"";
  position:absolute;
  left:13%;
  right:13%;
  bottom:17%;
  height:18px;
  border-radius:50%;
  background:rgba(61,55,44,.12);
  filter:blur(12px);
}
.home24-object-plane{
  position:absolute;
  display:flex;
  flex-direction:column;
  justify-content:space-between;
  padding:22px;
  border:1px solid rgba(30,31,27,.13);
  background:#f8f5ef;
}
.home24-object-plane span{font:600 9px/1 var(--font-mono);letter-spacing:.12em;text-transform:uppercase;color:#7b7e78}
.home24-object-plane i{display:block;border-radius:50% 50% 45% 55%;background:linear-gradient(145deg,#d7d0c3,#f3eee5 52%,#bbb1a3);box-shadow:0 34px 60px rgba(54,48,39,.16)}
.home24-object-plane-a{left:10%;top:9%;width:44%;height:66%}
.home24-object-plane-a i{width:68%;aspect-ratio:1;margin:auto}
.home24-object-plane-b{right:8%;top:18%;width:31%;height:43%;background:#e3d6c2}
.home24-object-plane-b i{width:55%;aspect-ratio:.82;margin:auto;background:linear-gradient(155deg,#8f7355,#d4b58c)}
.home24-object-ledger{
  position:absolute;
  right:8%;
  bottom:7%;
  width:45%;
  display:grid;
  grid-template-columns:1fr auto;
  gap:0;
  border-top:1px solid rgba(23,26,24,.2);
}
.home24-object-ledger span,.home24-object-ledger b{padding:10px 0;border-bottom:1px solid rgba(23,26,24,.14);font-size:11px}
.home24-object-ledger span{color:#747a73}
.home24-object-ledger b{text-align:right;font-weight:650}

.home24-world-place{background:#f1ede4}
.home24-place-stage{position:relative;min-height:590px;background:#dcd4c5;overflow:hidden}
.home24-place-gridlines{
  position:absolute;inset:0;opacity:.34;
  background-image:linear-gradient(rgba(50,56,48,.13) 1px,transparent 1px),linear-gradient(90deg,rgba(50,56,48,.13) 1px,transparent 1px);
  background-size:70px 70px;
}
.home24-contours{position:absolute;inset:12% 8% 13%}
.home24-contours i{position:absolute;border:1px solid rgba(59,71,57,.34);border-radius:48% 52% 44% 56% / 58% 40% 60% 42%;transform:rotate(-8deg)}
.home24-contours i:nth-child(1){inset:3% 4%}
.home24-contours i:nth-child(2){inset:11% 13%;transform:rotate(5deg)}
.home24-contours i:nth-child(3){inset:22% 24%;transform:rotate(-13deg)}
.home24-contours i:nth-child(4){inset:34% 35%;transform:rotate(9deg)}
.home24-contours i:nth-child(5){inset:44% 43%;transform:rotate(-5deg)}
.home24-place-pin{position:absolute;left:56%;top:43%;width:16px;height:16px;border-radius:50%;background:#254b38;box-shadow:0 0 0 8px rgba(37,75,56,.14)}
.home24-place-caption{position:absolute;left:28px;bottom:26px;display:flex;flex-direction:column;gap:5px}
.home24-place-caption span{font:600 9px/1 var(--font-mono);letter-spacing:.13em;text-transform:uppercase;color:#657064}
.home24-place-caption strong{font:500 26px/1 var(--font-display);letter-spacing:-.04em}

.home24-world-movement{background:var(--h24-movement);color:#f4f1e9}
.home24-world-copy-light .home24-world-number{color:rgba(244,241,233,.45)}
.home24-world-copy-light p{color:rgba(244,241,233,.58)}
.home24-text-link-light{color:#f4f1e9}
.home24-route-stage{min-height:510px;padding:44px 42px;border:1px solid rgba(255,255,255,.13);background:rgba(255,255,255,.025)}
.home24-route-head{display:flex;justify-content:space-between;font:600 9px/1 var(--font-mono);letter-spacing:.13em;text-transform:uppercase;color:rgba(255,255,255,.46)}
.home24-route-line{position:relative;height:2px;margin:118px 18px 96px;background:rgba(255,255,255,.14)}
.home24-route-fill{position:absolute;left:0;top:0;height:100%;width:66%;background:#a9cdb9}
.home24-route-node{position:absolute;top:50%;width:16px;height:16px;border-radius:50%;border:2px solid #0c1714;background:#a9cdb9;box-shadow:0 0 0 6px rgba(169,205,185,.12);transform:translate(-50%,-50%)}
.home24-route-node-a{left:0}
.home24-route-node-b{left:50%}
.home24-route-node-c{left:100%;background:#0c1714;border-color:rgba(255,255,255,.38);box-shadow:0 0 0 6px rgba(255,255,255,.05)}
.home24-route-record{display:grid;grid-template-columns:1fr auto;border-top:1px solid rgba(255,255,255,.16)}
.home24-route-record span,.home24-route-record strong{padding:13px 0;border-bottom:1px solid rgba(255,255,255,.11);font-size:11px}
.home24-route-record span{color:rgba(255,255,255,.4)}
.home24-route-record strong{font-weight:600;color:#d9e7df}

/* TRUST */
.home24-trust{padding:130px 0;background:#f6f3ec}
.home24-trust-head{display:grid;grid-template-columns:.52fr 1fr;column-gap:80px;align-items:start}
.home24-trust-head .home24-kicker{grid-column:1;margin-top:11px}
.home24-trust-head h2{grid-column:2}
.home24-trust-head p{grid-column:2;max-width:600px;margin-top:28px;font-size:15px;line-height:1.76;color:#656b65}
.home24-trust-ledger{margin-top:86px;border-top:1px solid var(--h24-line)}
.home24-trust-ledger>div{
  display:grid;
  grid-template-columns:80px 220px minmax(0,1fr);
  gap:30px;
  align-items:start;
  padding:26px 0;
  border-bottom:1px solid var(--h24-line);
}
.home24-trust-ledger span{font:500 10px/1 var(--font-mono);color:#8a8f89;padding-top:4px}
.home24-trust-ledger strong{font:500 22px/1 var(--font-display);letter-spacing:-.035em}
.home24-trust-ledger p{max-width:620px;font-size:13px;line-height:1.6;color:#6b716b}

/* PARTICIPATE */
.home24-participate{padding:116px 0 128px;background:#e8e3d9}
.home24-participate-head{display:grid;grid-template-columns:.52fr 1fr;gap:80px;align-items:start;margin-bottom:70px}
.home24-participate-head h2{font-size:clamp(44px,4.5vw,68px)}
.home24-participate-head .home24-kicker{padding-top:11px}
.home24-participate-grid{border-top:1px solid var(--h24-line)}
.home24-participate-row{
  display:grid;
  grid-template-columns:240px minmax(0,1fr) 24px;
  gap:28px;
  align-items:center;
  min-height:92px;
  padding:18px 0;
  border-bottom:1px solid var(--h24-line);
  color:var(--h24-ink);
  text-decoration:none;
}
.home24-participate-row>span{display:flex;align-items:center;gap:12px;font:600 14px/1 var(--font-display)}
.home24-participate-row p{max-width:620px;font-size:13px;line-height:1.55;color:#6a7069}
.home24-participate-row>svg{transition:transform .25s var(--ease)}
.home24-participate-row:hover>svg{transform:translateX(4px)}

/* RESPONSIVE ART DIRECTION */
@media(min-width:1600px){
  .home24-shell{width:min(1500px,calc(100% - 144px))}
  .home24-hero{padding-top:110px;padding-bottom:120px}
  .home24-hero-grid,.home24-world-grid{gap:150px}
  .home24-object-stage,.home24-place-stage{min-height:650px}
}
@media(min-width:1180px) and (max-width:1599px){
  .home24-shell{width:min(1280px,calc(100% - 72px))}
  .home24-hero-grid,.home24-world-grid{gap:70px}
}
@media(min-width:768px) and (max-width:1179px){
  .home24-shell{width:min(900px,calc(100% - 48px))}
  .home24-hero{padding:68px 0 80px}
  .home24-hero-grid{grid-template-columns:1fr;gap:62px}
  .home24-hero-copy{max-width:780px}
  .home24-hero-copy h1{font-size:clamp(64px,10vw,92px)}
  .home24-index-row{min-height:132px}
  .home24-world{padding:94px 0}
  .home24-world-grid,.home24-world-grid-reverse{grid-template-columns:1fr;gap:62px}
  .home24-world-copy{max-width:650px}
  .home24-world-grid-reverse .home24-world-copy{order:-1}
  .home24-object-stage,.home24-place-stage{min-height:540px}
  .home24-trust,.home24-participate{padding:96px 0}
  .home24-trust-head,.home24-participate-head{grid-template-columns:1fr;gap:24px}
  .home24-trust-head .home24-kicker,.home24-trust-head h2,.home24-trust-head p{grid-column:1}
}
@media(max-width:767px){
  .home24-shell{width:calc(100% - 32px)}
  .home24-hero{padding:48px 0 58px}
  .home24-hero-grid{grid-template-columns:1fr;gap:48px}
  .home24-hero-copy h1{font-size:clamp(50px,15vw,68px);margin-top:18px}
  .home24-hero-copy>p{font-size:15px}
  .home24-entry-actions{align-items:stretch;flex-direction:column}
  .home24-action{width:100%}
  .home24-hero-note{display:grid;gap:8px}
  .home24-index-row{grid-template-columns:30px minmax(0,1fr) 18px;gap:14px;min-height:auto;padding:24px 0}
  .home24-index-row:hover{padding-left:0;padding-right:0}
  .home24-index-row strong{font-size:27px}
  .home24-world{padding:72px 0}
  .home24-world-grid,.home24-world-grid-reverse{grid-template-columns:1fr;gap:44px}
  .home24-world-grid-reverse .home24-world-copy{order:-1}
  .home24-world-copy h2,.home24-trust-head h2{font-size:clamp(42px,12vw,56px)}
  .home24-object-stage{min-height:430px}
  .home24-object-plane-a{left:6%;top:7%;width:55%;height:60%}
  .home24-object-plane-b{right:5%;top:20%;width:35%;height:37%}
  .home24-object-ledger{left:6%;right:6%;bottom:5%;width:auto}
  .home24-place-stage{min-height:440px}
  .home24-route-stage{min-height:400px;padding:30px 22px}
  .home24-route-line{margin:94px 8px 72px}
  .home24-trust{padding:78px 0}
  .home24-trust-head{display:block}
  .home24-trust-head h2{margin-top:20px}
  .home24-trust-head p{margin-top:22px}
  .home24-trust-ledger{margin-top:56px}
  .home24-trust-ledger>div{grid-template-columns:38px 1fr;gap:14px 18px;padding:22px 0}
  .home24-trust-ledger p{grid-column:2}
  .home24-participate{padding:78px 0 90px}
  .home24-participate-head{display:block;margin-bottom:48px}
  .home24-participate-head h2{font-size:44px;margin-top:20px}
  .home24-participate-row{grid-template-columns:1fr 20px;gap:8px 16px;padding:20px 0}
  .home24-participate-row>span{grid-column:1}
  .home24-participate-row>p{grid-column:1;font-size:12px}
  .home24-participate-row>svg{grid-column:2;grid-row:1/3}
}
@media(max-width:390px){
  .home24-shell{width:calc(100% - 24px)}
  .home24-hero-copy h1{font-size:49px}
  .home24-world-copy h2,.home24-trust-head h2{font-size:40px}
  .home24-object-stage{min-height:390px}
  .home24-place-stage{min-height:400px}
  .home24-participate-head h2{font-size:39px}
}
@media(prefers-reduced-motion:reduce){
  .home24-index-row,.home24-participate-row>svg{transition:none}
}
</style>
