<script setup>
import { ref, onMounted, inject } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import { supabase } from '../lib/supabase'

const router = useRouter()
const toast = inject('toast')
const { session, signOut, reloadProfile } = useAuth()
const email = ref('')

onMounted(() => { email.value = session.value?.user?.email || '(no email — anonymous session)' })

async function recheck() {
  await reloadProfile()
  const { profile } = useAuth()
  if (profile.value?.role) router.push(profile.value.role === 'driver' ? '/driver' : '/dispatch')
  else toast('Still no profile linked — run the SQL below, then re-check', 'warn')
}
async function logout() { await signOut(); router.push('/login') }

const myId = session.value?.user?.id || ''
</script>

<template>
  <div class="auth-wrap">
    <div class="auth-card">
      <div class="auth-brand">
        <div class="auth-logo">
          <svg viewBox="0 0 24 24" width="26" height="26" fill="none">
            <path d="M3 8l9-5 9 5v8l-9 5-9-5V8z" stroke="#0B0D11" stroke-width="1.6" stroke-linejoin="round"/>
            <path d="M3 8l9 5 9-5M12 13v8" stroke="#0B0D11" stroke-width="1.6" stroke-linejoin="round"/>
          </svg>
        </div>
        <div><h1 style="font-size:22px">Almost there</h1></div>
      </div>

      <div class="panel">
        <p style="color:var(--ink-2);font-size:14px;margin-bottom:14px">
          You're signed in as <b>{{ email }}</b>, but this account isn't linked to a carrier yet.
        </p>
        <p style="color:var(--ink-3);font-size:12.5px;margin-bottom:8px">Run this once in the Supabase SQL Editor:</p>
        <pre style="background:var(--panel-2);border:1px solid var(--line);border-radius:10px;padding:12px;font-size:11px;overflow-x:auto;color:var(--ink-2);white-space:pre-wrap">insert into profile (user_id, carrier_id, role, name)
values ('{{ myId }}',
        (select id from carrier where slug='usiri'),
        'dispatch', 'Baraka')
on conflict (user_id) do update
  set carrier_id = excluded.carrier_id, role = excluded.role;</pre>
        <button class="btn btn-accent btn-block btn-lg" style="margin-top:14px" @click="recheck">I've run it — take me in</button>
        <button class="btn btn-ghost btn-block" style="margin-top:9px" @click="logout">Sign out</button>
      </div>
    </div>
  </div>
</template>
