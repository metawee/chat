import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import CrmLaunch from '../CrmLaunch.vue';
import ShawkyAPI from 'dashboard/shawky/api/shawky';
import en from 'dashboard/shawky/i18n/en.json';

const replace = vi.fn();
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1' } }),
  useRouter: () => ({ replace }),
}));
vi.mock('dashboard/shawky/api/shawky', () => ({
  default: { completeCrmLaunch: vi.fn() },
}));

const i18n = createI18n({ legacy: false, locale: 'en', messages: { en } });
const mountPage = () =>
  mount(CrmLaunch, {
    global: { plugins: [i18n], stubs: { Spinner: true } },
  });

describe('CrmLaunch', () => {
  beforeEach(() => vi.clearAllMocks());

  it('opens the conversation with the template picker when the window is closed', async () => {
    ShawkyAPI.completeCrmLaunch.mockResolvedValue({
      data: { conversation_id: 42, needs_template: true },
    });
    mountPage();
    await flushPromises();

    expect(replace).toHaveBeenCalledWith({
      path: '/app/accounts/1/conversations/42',
      query: { shawky_open_templates: 1 },
    });
  });

  it('explains why the launch failed', async () => {
    ShawkyAPI.completeCrmLaunch.mockRejectedValue({
      response: { data: { error: 'not_allowed' } },
    });
    const wrapper = mountPage();
    await flushPromises();

    expect(wrapper.text()).toContain('This customer is not assigned to you.');
  });
});
