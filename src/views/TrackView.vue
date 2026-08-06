<script setup>
import { ref, onMounted, inject, computed } from 'vue'
import { useRoute } from 'vue-router'
import { supabase, fmtTZS } from '../lib/supabase'
import Icon from '../components/Icon.vue'
import Spinner from '../components/Spinner.vue'
import EmptyState from '../components/EmptyState.vue'

const route = useRoute()
const toast = inject('toast')
const code = ref((route.params.code || '').toString().toUpperCase())
const parcel = ref(null)
const notFound = ref(false)
const busy = ref(false)
const searched = ref(false)

const STAGE_ORDER = ['booked','collected','linehaul','with_driver','delivered','confirmed']
const STAGE_CAP = { booked:'Booked', collected:'Carrier has it', linehaul:'On road', with_driver:'With driver', delivered:'Delivered', confirmed:'Confirmed', failed:'Failed' }

async function track() {
  if (!code.value) return
  busy.value = true; notFound.value = false
  const { data, error } = await supabase.rpc('track_parcel', { p_code: code.value })
  busy.value = false; searched.value = true
  if (error || !data || !data.length) { notFound.value = true; parcel.value = null; return }
  const r = data[0]
  parcel.value = {
    code: r.code, receiver: r.receiver_name, addr: r.dest_address, item: r.item, weight: r.weight_kg,
    stage: r.stage, driver: r.driver_name, carrier: r.carrier_name, accent: r.carrier_accent,
    payMode: r.pay_mode, payState: r.pay_state, cod: r.cod_amount, fee: r.fee_amount,
    podPhoto: r.pod_photo_url, podAt: r.pod_at,
  }
  if (r.carrier_accent) document.documentElement.style.setProperty('--accent', r.carrier_accent)
}
async function confirm() {
  busy.value = true
  const { error } = await supabase.rpc('confirm_receipt', { p_code: code.value })
  busy.value = false
  if (error) { toast('Not able to confirm yet', 'warn'); return }
  toast('Receipt confirmed — asante!', 'ok'); track()
}
function stageOn(s, i) {
  if (parcel.value.stage === 'failed') return i <= STAGE_ORDER.indexOf('with_driver')
  return i <= STAGE_ORDER.indexOf(parcel.value.stage)
}
const owed = computed(() => (parcel.value?.payMode==='cash' && !['collected','remitted','settled'].includes(parcel.value?.payState)) ? parcel.value.cod : 0)
onMounted(() => { if (code.value) track() })
</script>

<template>
  <div class="topbar"><div class="inner">
    <div class="tb-mark">{{ (parcel?.carrier || 'EC').slice(0,2).toUpperCase() }}</div>
    <div><div class="tb-name">{{ parcel?.carrier || 'Enkiama Cargos' }}</div><div class="tb-role">Track your parcel</div></div>
    <div class="tb-spacer"></div>
    <div class="tb-enk">powered by<br><b>Enkiama Cargos</b></div>
  </div></div>

  <div class="wrap" style="max-width:560px">
    <div class="panel">
      <div class="fg" style="position:relative">
        <label>Tracking code</label>
        <input v-model="code" class="mono" placeholder="USR-XXXX" style="text-transform:uppercase" @keyup.enter="track" />
      </div>
      <button class="btn btn-accent btn-block btn-lg" :disabled="busy" @click="track">
        <Spinner v-if="busy" :size="16" /><template v-else>Track parcel</template>
      </button>
    </div>

    <EmptyState v-if="notFound" icon="search" title="No parcel with that code" hint="Check the code your sender shared with you." />

    <div v-if="parcel" class="cons">
      <div class="cons-hd">
        <div class="grow">
          <div class="cons-code mono">{{ parcel.code }}</div>
          <div class="cons-rte">{{ parcel.driver ? 'With ' + parcel.driver : 'Not yet with a driver' }}</div>
        </div>
        <span class="paychip" :class="parcel.stage==='confirmed'?'pay-settled':parcel.stage==='failed'?'pay-cod':'pay-collected'">{{ STAGE_CAP[parcel.stage] }}</span>
      </div>
      <div class="cons-bd">
        <div class="party">
          <div><div class="p-lab">To</div><div class="p-val">{{ parcel.receiver }}</div><div class="p-sub">{{ parcel.addr }}</div></div>
          <div style="text-align:right"><div class="p-lab">Parcel</div><div class="p-val">{{ parcel.item }}</div><div class="p-sub">{{ parcel.weight }}kg</div></div>
        </div>

        <div class="wb-sec">
          <div class="trk-lab"><Icon name="link" :size="12" /> Where it is</div>
          <div class="custody">
            <div v-for="(s,i) in STAGE_ORDER" :key="s" class="cst" :class="{on:stageOn(s,i)}">
              <div class="pt"></div><div class="cap">{{ STAGE_CAP[s] }}</div>
            </div>
          </div>
        </div>

        <div v-if="owed>0" class="money-bar owed" style="margin-top:16px">
          <Icon name="cash" :size="16" /><span class="m-txt">Have this ready for the driver</span><span class="m-amt mono">{{ fmtTZS(owed) }}</span>
        </div>

        <!-- proof shown once delivered -->
        <div v-if="parcel.podPhoto" class="wb-sec" style="margin-top:16px">
          <div class="trk-lab"><Icon name="camera" :size="12" /> Proof of delivery</div>
          <img :src="parcel.podPhoto" style="width:100%;border-radius:12px;margin-top:8px;max-height:220px;object-fit:cover" />
        </div>

        <div class="cons-actions">
          <button v-if="parcel.stage==='delivered'" class="btn btn-go btn-block btn-lg" :disabled="busy" @click="confirm">
            <Icon name="check" :size="18" /> Confirm I received it
          </button>
          <div v-else-if="parcel.stage==='confirmed'" class="money-bar done" style="width:100%">
            <Icon name="check" :size="16" /><span class="m-txt">Delivery confirmed — asante!</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
