import { createRouter, createWebHistory } from 'vue-router'
import LoginPage from '../views/LoginPage.vue'
import BossSelection from '../views/BossSelection.vue'
import BattlePage from '../views/BattlePage.vue'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      name: 'login',
      component: LoginPage
    },
    {
      path: '/boss-selection',
      name: 'boss-selection',
      component: BossSelection
    },
    {
      path: '/battle',
      name: 'battle',
      component: BattlePage
    },
    {
      path: '/:pathMatch(.*)*',
      redirect: '/'
    }
  ]
})

export default router