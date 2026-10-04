let leafletPromise = null

export async function loadLeaflet() {
  if (!leafletPromise) {
    leafletPromise = Promise.all([
      import('leaflet'),
      import('leaflet/dist/leaflet.css'),
    ])
      .then(([mod]) => mod.default || mod)
      .catch((error) => {
        leafletPromise = null
        throw error
      })
  }
  return leafletPromise
}
