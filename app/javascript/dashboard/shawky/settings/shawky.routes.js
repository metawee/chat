import { frontendURL } from 'dashboard/helper/URLHelper';
import SettingsWrapper from 'dashboard/routes/dashboard/settings/SettingsWrapper.vue';
import Index from './Index.vue';

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
      ],
    },
  ],
};
