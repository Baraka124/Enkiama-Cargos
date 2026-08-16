import { ref, computed } from 'vue'

// Lightweight i18n — English + Swahili. Persisted to localStorage.
const lang = ref(localStorage.getItem('enkiama_lang') || 'en')

const DICT = {
  en: {
    signIn: 'Sign in', signOut: 'Sign out', dispatch: 'Dispatch', driver: 'Driver',
    needsAction: 'Needs action', ledger: 'Ledger', customers: 'Customers', team: 'Team',
    newConsignment: 'New consignment', book: 'Book consignment', search: 'Search…',
    activeConsignments: 'Active consignments', cashToCollect: 'Cash to collect',
    onRoad: 'On the road', delivered: 'Delivered', receiver: 'Receiver', sender: 'Sender',
    markCollected: 'Mark collected', sendOnRoad: 'Send on road', assignDriver: 'Assign local driver',
    handedToDriver: 'Handed to driver', scheduleRetry: 'Schedule retry', returnToSender: 'Return to sender',
    confirmRemit: 'Confirm cash remitted', dashboard: 'Dashboard', today: 'Today',
    sendParcel: 'Send a parcel', myParcels: 'My parcels', trackParcel: 'Track your parcel',
    nothingToCollect: 'Nothing to collect', collectCash: 'Collect cash', couldntDeliver: "Couldn't deliver",
    proofOfDelivery: 'Proof of delivery', confirmDelivery: 'Confirm delivery',
  },
  sw: {
    signIn: 'Ingia', signOut: 'Toka', dispatch: 'Uratibu', driver: 'Dereva',
    needsAction: 'Yanahitaji hatua', ledger: 'Daftari', customers: 'Wateja', team: 'Timu',
    newConsignment: 'Mzigo mpya', book: 'Sajili mzigo', search: 'Tafuta…',
    activeConsignments: 'Mizigo hai', cashToCollect: 'Fedha za kukusanya',
    onRoad: 'Njiani', delivered: 'Imefikishwa', receiver: 'Mpokeaji', sender: 'Mtumaji',
    markCollected: 'Imepokelewa', sendOnRoad: 'Peleka njiani', assignDriver: 'Mpe dereva',
    handedToDriver: 'Kabidhi kwa dereva', scheduleRetry: 'Panga kujaribu tena', returnToSender: 'Rudisha kwa mtumaji',
    confirmRemit: 'Thibitisha fedha zimewasilishwa', dashboard: 'Dashibodi', today: 'Leo',
    sendParcel: 'Tuma mzigo', myParcels: 'Mizigo yangu', trackParcel: 'Fuatilia mzigo wako',
    nothingToCollect: 'Hakuna cha kukusanya', collectCash: 'Kusanya fedha', couldntDeliver: 'Imeshindikana',
    proofOfDelivery: 'Uthibitisho wa kufikisha', confirmDelivery: 'Thibitisha kufikisha',
  },
}

function setLang(l) { lang.value = l; localStorage.setItem('enkiama_lang', l) }

export function useI18n() {
  const t = (key) => (DICT[lang.value] && DICT[lang.value][key]) || DICT.en[key] || key
  return { lang, setLang, t, isSwahili: computed(() => lang.value === 'sw') }
}
