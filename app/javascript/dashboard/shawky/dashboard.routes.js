import { frontendURL } from 'dashboard/helper/URLHelper';
import FollowUps from './pages/FollowUps.vue';

// Pages shown inside the dashboard layout (with the sidebar).
export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/shawky/follow-ups'),
      name: 'shawky_follow_ups',
      meta: { permissions: ['administrator', 'agent', 'custom_role'] },
      component: FollowUps,
    },
  ],
};
