import { mount, flushPromises } from '@vue/test-utils';
import { ref } from 'vue';
import { createI18n } from 'vue-i18n';
import RevealPhoneButton from '../RevealPhoneButton.vue';
import ShawkyAPI from 'dashboard/shawky/api/shawky';
import { useAdmin } from 'dashboard/composables/useAdmin';
import en from 'dashboard/shawky/i18n/en.json';

vi.mock('dashboard/composables/useAdmin', () => ({ useAdmin: vi.fn() }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/shawky/composables/useShawkyRouting', () => ({
  useShawkyRouting: () => ({ routing: ref({ phone_masking_enabled: true }) }),
}));
vi.mock('dashboard/shawky/api/shawky', () => ({
  default: { revealPhone: vi.fn() },
}));

const i18n = createI18n({ legacy: false, locale: 'en', messages: { en } });

const mountButton = () =>
  mount(RevealPhoneButton, {
    props: { contactId: 7 },
    global: { plugins: [i18n] },
  });

describe('RevealPhoneButton', () => {
  beforeEach(() => vi.clearAllMocks());

  it('is not rendered for non-administrators', () => {
    useAdmin.mockReturnValue({ isAdmin: ref(false) });

    expect(mountButton().html()).not.toContain('Show number');
  });

  it('asks the server for the number and shows it', async () => {
    useAdmin.mockReturnValue({ isAdmin: ref(true) });
    ShawkyAPI.revealPhone.mockResolvedValue({
      data: { phone_number: '+966542921507' },
    });

    const wrapper = mountButton();
    await wrapper.find('button').trigger('click');
    await flushPromises();

    expect(ShawkyAPI.revealPhone).toHaveBeenCalledWith(7);
    expect(wrapper.text()).toContain('+966542921507');
  });
});
