import { mount } from '@vue/test-utils';
import { ref } from 'vue';
import { createI18n } from 'vue-i18n';
import ConversationNumberBar from '../ConversationNumberBar.vue';
import { useShawkyRouting } from 'dashboard/shawky/composables/useShawkyRouting';
import en from 'dashboard/shawky/i18n/en.json';

vi.mock('dashboard/shawky/composables/useShawkyRouting', () => ({
  useShawkyRouting: vi.fn(),
}));
vi.mock('vue-router', () => ({ useRouter: () => ({ push: vi.fn() }) }));
vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ getters: { getCurrentAccountId: 1 } }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const i18n = createI18n({ legacy: false, locale: 'en', messages: { en } });
const nowSeconds = () => Math.floor(Date.now() / 1000);

const mountBar = (chat, routing = {}) => {
  useShawkyRouting.mockReturnValue({ routing: ref(routing) });
  return mount(ConversationNumberBar, {
    props: { chat },
    global: { plugins: [i18n] },
  });
};

describe('ConversationNumberBar', () => {
  it('shows the time left in the 24-hour window', () => {
    const wrapper = mountBar({
      id: 1,
      inbox_id: 1,
      shawky_window_closes_at: nowSeconds() + 3 * 3600 + 20 * 60,
    });

    expect(wrapper.text()).toContain('Window: 3h 20m left');
  });

  it('says the window is closed once it expired', () => {
    const wrapper = mountBar({
      id: 1,
      inbox_id: 1,
      shawky_window_closes_at: nowSeconds() - 60,
    });

    expect(wrapper.text()).toContain('Window closed: template only');
  });

  it('offers to continue on the active number after a failover', () => {
    const routing = {
      primary_inbox_id: 1,
      backup_inbox_id: 2,
      active_inbox_id: 2,
    };

    expect(
      mountBar({ id: 1, inbox_id: 1 }, routing).find('button').exists()
    ).toBe(true);
    expect(
      mountBar({ id: 1, inbox_id: 2 }, routing).find('button').exists()
    ).toBe(false);
  });
});
