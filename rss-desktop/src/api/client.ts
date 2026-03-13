import axios from 'axios'

const api = axios.create({
  baseURL: import.meta.env.DEV ? '/api' : (import.meta.env.VITE_API_BASE_URL ?? 'http://127.0.0.1:27496/api'),
  timeout: 15000,
})

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('rss-auth-token')
  if (token) {
    config.headers = config.headers || {}
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response && error.response.status === 401) {
      // Dispatch a custom event so the main app can handle logout/UI
      window.dispatchEvent(new CustomEvent('auth:unauthorized'))
    }
    return Promise.reject(error)
  }
)

export default api
