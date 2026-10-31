import { frontendURL } from 'dashboard/helper/URLHelper';
import SettingsWrapper from 'dashboard/routes/dashboard/settings/SettingsWrapper.vue';
import Index from './Index.vue';
import Reports from './Reports.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/shawky'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'shawky_settings',
          meta: { permissions: ['administrator'] },
          component: Index,
        },
        {
          path: 'reports',
          name: 'shawky_reports',
          meta: { permissions: ['administrator'] },
          component: Reports,
        },
      ],
    },
  ],
};
