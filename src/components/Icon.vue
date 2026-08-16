<script setup>
// Self-contained line-icon set — uniform 1.6 stroke, 24-grid, currentColor.
// No dependency; deploys clean. Use: <Icon name="truck" :size="18" />
defineProps({ name: String, size: { type: [Number, String], default: 18 }, stroke: { type: [Number, String], default: 1.6 } })
const P = {
  // ── freight-domain signature icons (what makes this set elite, not generic) ──
  waybill: '<rect x="5" y="3" width="14" height="18" rx="2"/><path d="M9 8h6M9 12h6M9 16h3"/><path d="M5 3v18" stroke-dasharray="1 2"/>',
  route: '<circle cx="6" cy="19" r="2"/><circle cx="18" cy="5" r="2"/><path d="M8 19h6a3 3 0 003-3V9a3 3 0 013-3" stroke-dasharray="0.1 3.2"/>',
  handoff: '<path d="M4 12l4-2 4 2 4-2 4 2"/><path d="M8 10V6a2 2 0 012-2h4a2 2 0 012 2v4"/><path d="M4 12v4a2 2 0 002 2h12a2 2 0 002-2v-4"/>',
  scale: '<path d="M12 3v18M7 21h10"/><path d="M12 6l-6 2 3 5a3 3 0 01-6 0l3-5M12 6l6 2-3 5a3 3 0 006 0l-3-5"/>',
  parcel: '<path d="M12 2l9 5v10l-9 5-9-5V7z"/><path d="M12 2v20M3 7l9 5 9-5" opacity=".9"/>',
  road: '<path d="M4 21L8 3M20 21L16 3M12 6v2M12 12v2M12 18v2"/>',
  truck: '<path d="M3 6h11v9H3z"/><path d="M14 9h4l3 3v3h-7z"/><circle cx="7" cy="18" r="1.6"/><circle cx="17" cy="18" r="1.6"/>',
  menu: '<path d="M4 6h16M4 12h16M4 18h16"/>',
  globe: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.5 2.5 2.5 15 0 18M12 3c-2.5 2.5-2.5 15 0 18"/>',
  moon: '<path d="M21 12.8A9 9 0 1111.2 3 7 7 0 0021 12.8z"/>',
  sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M19.1 4.9l-1.4 1.4M6.3 17.7l-1.4 1.4"/>',
  package: '<path d="M12 3l8 4.5v9L12 21l-8-4.5v-9z"/><path d="M4 7.5l8 4.5 8-4.5M12 12v9"/>',
  pin: '<path d="M12 21s-6-5.3-6-10a6 6 0 1112 0c0 4.7-6 10-6 10z"/><circle cx="12" cy="11" r="2.2"/>',
  cash: '<rect x="3" y="6" width="18" height="12" rx="2"/><circle cx="12" cy="12" r="2.4"/><path d="M6 9v6M18 9v6"/>',
  link: '<path d="M9 15l6-6"/><path d="M10.5 6.5l1-1a3.5 3.5 0 015 5l-1 1M13.5 17.5l-1 1a3.5 3.5 0 01-5-5l1-1"/>',
  phone: '<path d="M6 3h3l1.5 5-2 1.2a11 11 0 005.3 5.3l1.2-2 5 1.5v3a2 2 0 01-2 2A16 16 0 014 5a2 2 0 012-2z"/>',
  check: '<path d="M5 12.5l4.5 4.5L19 7"/>',
  clock: '<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>',
  user: '<circle cx="12" cy="8" r="3.5"/><path d="M5.5 19a6.5 6.5 0 0113 0"/>',
  users: '<circle cx="9" cy="8" r="3"/><path d="M3.5 19a5.5 5.5 0 0111 0"/><path d="M16 5.2a3 3 0 010 5.6M21 19a5.5 5.5 0 00-4-5.3"/>',
  search: '<circle cx="11" cy="11" r="6.5"/><path d="M20 20l-3.5-3.5"/>',
  plus: '<path d="M12 5v14M5 12h14"/>',
  send: '<path d="M21 3L10.5 13.5M21 3l-6.5 18-4-8-8-4z"/>',
  lock: '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>',
  star: '<path d="M12 3l2.6 5.3 5.9.9-4.3 4.1 1 5.8-5.2-2.7-5.2 2.7 1-5.8-4.3-4.1 5.9-.9z"/>',
  bike: '<circle cx="6" cy="17" r="3"/><circle cx="18" cy="17" r="3"/><path d="M6 17l4-8h5l3 8M9 9h5"/>',
  chart: '<path d="M4 20V4M4 20h16M8 16v-4M12 16V8M16 16v-6"/>',
  swap: '<path d="M7 4L3 8l4 4M3 8h13M17 20l4-4-4-4M21 16H8"/>',
  signout: '<path d="M14 4h4a1 1 0 011 1v14a1 1 0 01-1 1h-4M10 8l-4 4 4 4M6 12h9"/>',
  building: '<rect x="5" y="3" width="14" height="18" rx="1"/><path d="M9 7h2M13 7h2M9 11h2M13 11h2M9 15h2M13 15h2"/>',
  shield: '<path d="M12 3l7 3v5c0 4.5-3 8-7 10-4-2-7-5.5-7-10V6z"/><path d="M9 12l2 2 4-4"/>',
  camera: '<rect x="3" y="7" width="18" height="13" rx="2"/><circle cx="12" cy="13.5" r="3.2"/><path d="M8 7l1.5-2.5h5L16 7"/>',
  pen: '<path d="M4 20l4-1L19 8a2 2 0 00-3-3L5 16z"/>',
  box: '<rect x="4" y="4" width="16" height="16" rx="2"/>',
  arrow: '<path d="M5 12h14M13 6l6 6-6 6"/>',
  inbox: '<path d="M4 13l2-8h12l2 8v5a1 1 0 01-1 1H5a1 1 0 01-1-1z"/><path d="M4 13h5l1 2h4l1-2h5"/>',
  alert: '<path d="M12 4l9 16H3z"/><path d="M12 10v4M12 17.5v.01"/>',
}
</script>
<template>
  <svg :width="size" :height="size" viewBox="0 0 24 24" fill="none"
       :stroke-width="stroke" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round"
       style="flex-shrink:0;display:inline-block;vertical-align:middle" v-html="P[name] || P.box"></svg>
</template>
