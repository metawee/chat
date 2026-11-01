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
      response: { data: { error: 'expired' } },
    });
    const wrapper = mountPage();
    await flushPromises();

    expect(wrapper.text()).toContain(
      'This CRM link has expired. Press the WhatsApp button in the CRM again.'
    );
  });

  it('shows a generic message for unexpected errors instead of a raw key', async () => {
    ShawkyAPI.completeCrmLaunch.mockRejectedValue({
      response: { data: { error: 'Resource could not be found' } },
    });
    const wrapper = mountPage();
    await flushPromises();

    expect(wrapper.text()).toContain(
      'Something went wrong. Try again from the CRM.'
    );
  });
});
