import { mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import SwitchesSection from '../SwitchesSection.vue';
import en from 'dashboard/shawky/i18n/en.json';

vi.mock('dashboard/shawky/api/shawky', () => ({
  default: { gatewayHealth: vi.fn() },
}));

const i18n = createI18n({ legacy: false, locale: 'en', messages: { en } });
const DialogStub = {
  props: ['title', 'description'],
  emits: ['confirm'],
  methods: { open: vi.fn(), close: vi.fn() },
  template:
    '<div class="dialog">{{ title }}<button class="confirm" @click="$emit(\'confirm\')" /></div>',
};
const SwitchStub = {
  props: ['modelValue'],
  emits: ['update:modelValue'],
  template:
    '<button class="switch" @click="$emit(\'update:modelValue\', !modelValue)" />',
};

const mountSection = settings =>
  mount(SwitchesSection, {
    props: { settings },
    global: {
      plugins: [i18n],
      stubs: { Dialog: DialogStub, Switch: SwitchStub },
    },
  });

describe('SwitchesSection', () => {
  it('asks for confirmation before saving a switch', async () => {
    const wrapper = mountSection({ phone_masking_enabled: false });

    await wrapper.find('.switch').trigger('click');
    expect(wrapper.emitted('save')).toBeUndefined();
    expect(wrapper.find('.dialog').text()).toContain('Turn on');

    await wrapper.find('.confirm').trigger('click');
    expect(wrapper.emitted('save')).toEqual([
      [{ phone_masking_enabled: true }],
    ]);
  });

  it('warns that masking is incomplete while it is on', () => {
    expect(mountSection({ phone_masking_enabled: true }).text()).toContain(
      'Number hiding is not complete'
    );
    expect(mountSection({ phone_masking_enabled: false }).text()).not.toContain(
      'Number hiding is not complete'
    );
  });
});
