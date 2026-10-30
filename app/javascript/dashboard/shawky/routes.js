import { frontendURL } from 'dashboard/helper/URLHelper';
import CrmLaunch from './pages/CrmLaunch.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/shawky/crm-launch'),
      name: 'shawky_crm_launch',
      meta: { permissions: ['administrator', 'agent', 'custom_role'] },
      component: CrmLaunch,
    },
  ],
};
