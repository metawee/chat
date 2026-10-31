import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import FollowUps from '../FollowUps.vue';
import ShawkyAPI from 'dashboard/shawky/api/shawky';
import en from 'dashboard/shawky/i18n/en.json';

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1' } }),
}));
vi.mock('dashboard/shawky/api/shawky', () => ({
  default: { getFollowUps: vi.fn() },
}));

const i18n = createI18n({ legacy: false, locale: 'en', messages: { en } });
const mountPage = () =>
  mount(FollowUps, {
    global: {
      plugins: [i18n],
      stubs: {
        Spinner: true,
        RouterLink: { props: ['to'], template: '<a :href="to"><slot /></a>' },
      },
    },
  });

describe('FollowUps', () => {
  it('links each waiting customer to the conversation', async () => {
    ShawkyAPI.getFollowUps.mockResolvedValue({
      data: {
        payload: [
          {
            id: 7,
            contact_name: 'منى',
            lead_id: 'L-555',
            assignee: { id: 2, name: 'Hasnaa' },
            last_agent_message_at: null,
          },
        ],
      },
    });
    const wrapper = mountPage();
    await flushPromises();

    expect(wrapper.text()).toContain('منى');
    expect(wrapper.text()).toContain('L-555');
    expect(wrapper.text()).toContain('No agent message yet');
    expect(wrapper.find('a').attributes('href')).toBe(
      '/app/accounts/1/conversations/7'
    );
  });

  it('says when there is nothing to follow up', async () => {
    ShawkyAPI.getFollowUps.mockResolvedValue({ data: { payload: [] } });
    const wrapper = mountPage();
    await flushPromises();

    expect(wrapper.text()).toContain('Nothing to follow up');
  });
});
