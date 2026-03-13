import { createRouter, createWebHashHistory } from 'vue-router'
import AppHome from '../views/AppHome.vue'
import { useUserStore } from '../stores/userStore'

const routes = [
  { path: '/', name: 'home', component: AppHome },
  { path: '/login', name: 'login', component: () => import('../views/Login.vue') },
  { path: '/channels', name: 'channels-square', component: () => import('../views/ChannelSquare.vue') },
  { 
    path: '/my-channels', 
    name: 'my-channels', 
    component: () => import('../views/MyChannels.vue'),
    meta: { requiresAuth: true }
  },
  { 
    path: '/my-channels/:id', 
    name: 'my-channel-detail', 
    component: AppHome,
    meta: { requiresAuth: true }
  },
  { path: '/admin/channels', name: 'admin-channels', component: () => import('../views/AdminChannels.vue'), meta: { requiresAuth: true, requiresAdmin: true } },
  { path: '/admin/feeds', name: 'admin-feeds', component: () => import('../views/AdminFeeds.vue'), meta: { requiresAuth: true, requiresAdmin: true } },
  { path: '/admin/users', name: 'admin-users', component: () => import('../views/AdminUsers.vue'), meta: { requiresAuth: true, requiresAdmin: true } },
  { path: '/admin/channels/:id/sources', name: 'admin-channel-sources', component: () => import('../views/AdminChannelSources.vue'), meta: { requiresAuth: true, requiresAdmin: true } },
  { path: '/admin/settings', name: 'admin-settings', component: () => import('../views/AdminSettings.vue'), meta: { requiresAuth: true, requiresAdmin: true } },
  { 
    path: '/reader/:id', 
    name: 'reader', 
    component: () => import('../views/ArticleReader.vue') 
  },
  { 
    path: '/trends', 
    name: 'trends', 
    component: () => import('../views/TrendsView.vue'),
    meta: { requiresAuth: true }
  },
  { 
    path: '/trends/:id', 
    name: 'topic-detail', 
    component: () => import('../views/TopicDetailView.vue'),
    meta: { requiresAuth: true }
  },
]

const router = createRouter({
  history: createWebHashHistory(),
  routes,
})

router.beforeEach(async (to, from, next) => {
  const userStore = useUserStore()
  
  // If has token but no profile, try fetch me (optional, but good for persistence)
  if (userStore.token && !userStore.profile) {
    try {
      await userStore.fetchMe()
    } catch (e) {
      // If fetch fails (token expired), logout but don't redirect (allow guest access)
      userStore.logout()
    }
  }

  if (to.meta.requiresAuth && !userStore.token) {
    next({ name: 'login', query: { redirect: to.fullPath } })
    return
  }

  if (to.meta.requiresAdmin && userStore.profile?.role !== 'admin') {
    next({ name: 'home' })
    return
  }

  next()
})

export default router
