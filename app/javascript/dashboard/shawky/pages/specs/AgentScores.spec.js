import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import AgentScores from '../AgentScores.vue';
import ShawkyAPI from 'dashboard/shawky/api/shawky';
import en from 'dashboard/shawky/i18n/en.json';

vi.mock('dashboard/shawky/api/shawky', () => ({
  default: { getAgentScores: vi.fn() },
}));

const i18n = createI18n({ legacy: false, locale: 'en', messages: { en } });
const mountPage = () =>
  mount(AgentScores, {
    global: { plugins: [i18n], stubs: { Spinner: true } },
  });

describe('AgentScores', () => {
  it('lists the weekly average per agent', async () => {
    ShawkyAPI.getAgentScores.mockResolvedValue({
      data: {
        payload: [
          {
            user_id: 1,
            name: 'Rawda',
            average_score: 82.5,
            reviewed_count: 4,
            flagged_count: 1,
            abuse_count: 0,
          },
        ],
      },
    });
    const wrapper = mountPage();
    await flushPromises();

    expect(wrapper.text()).toContain('Rawda');
    expect(wrapper.text()).toContain('82.5');
  });

  it('says when nothing was reviewed', async () => {
    ShawkyAPI.getAgentScores.mockResolvedValue({ data: { payload: [] } });
    const wrapper = mountPage();
    await flushPromises();

    expect(wrapper.text()).toContain('No reviewed conversations this week.');
  });
});
