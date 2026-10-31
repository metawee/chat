<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import ShawkyAPI from 'dashboard/shawky/api/shawky';
import { SETTING_SWITCHES } from 'dashboard/shawky/constants';

const props = defineProps({
  settings: { type: Object, required: true },
});
const emit = defineEmits(['save']);

const { t } = useI18n();
const dialogRef = ref(null);
const pendingChange = ref(null);
const gatewayStatus = ref('');

const pendingTitle = computed(() => {
  if (!pendingChange.value) return '';
  const name = t(
    `SHAWKY.SETTINGS.SWITCHES.${pendingChange.value.i18nKey}.LABEL`
  );
  return pendingChange.value.value
    ? t('SHAWKY.SETTINGS.SWITCHES.CONFIRM_ON', { name })
    : t('SHAWKY.SETTINGS.SWITCHES.CONFIRM_OFF', { name });
});

const requestChange = (item, value) => {
  pendingChange.value = { ...item, value };
  dialogRef.value?.open();
};

const confirmChange = () => {
  emit('save', { [pendingChange.value.key]: pendingChange.value.value });
  dialogRef.value?.close();
};

const testGateway = async () => {
  gatewayStatus.value = 'CHECKING';
  try {
    const { data } = await ShawkyAPI.gatewayHealth();
    gatewayStatus.value = data.ok ? 'OK' : 'FAILED';
  } catch {
    gatewayStatus.value = 'FAILED';
  }
};
</script>

<template>
  <section class="flex flex-col gap-4">
    <div
      v-for="item in SETTING_SWITCHES"
      :key="item.key"
      class="flex items-start justify-between gap-4"
    >
      <div class="flex flex-col gap-1">
        <span class="text-heading-3 text-n-slate-12">
          {{ t(`SHAWKY.SETTINGS.SWITCHES.${item.i18nKey}.LABEL`) }}
        </span>
        <span class="text-body-main text-n-slate-11">
          {{ t(`SHAWKY.SETTINGS.SWITCHES.${item.i18nKey}.DESCRIPTION`) }}
        </span>
      </div>
      <Switch
        :model-value="props.settings[item.key] === true"
        @update:model-value="value => requestChange(item, value)"
      />
    </div>

    <p
      v-if="props.settings.phone_masking_enabled"
      class="px-3 py-2 rounded-lg bg-n-amber-3 text-n-amber-11 text-body-main"
    >
      {{ t('SHAWKY.SETTINGS.SWITCHES.MASKING_WARNING') }}
    </p>

    <div class="flex flex-wrap items-center gap-3">
      <span class="text-body-main text-n-slate-11">
        {{
          props.settings.gateway_configured
            ? t('SHAWKY.SETTINGS.GATEWAY.CONFIGURED')
            : t('SHAWKY.SETTINGS.GATEWAY.NOT_CONFIGURED')
        }}
      </span>
      <NextButton
        :label="t('SHAWKY.SETTINGS.GATEWAY.TEST')"
        :is-loading="gatewayStatus === 'CHECKING'"
        sm
        faded
        @click="testGateway"
      />
      <span
        v-if="gatewayStatus && gatewayStatus !== 'CHECKING'"
        class="text-body-main"
        :class="gatewayStatus === 'OK' ? 'text-n-teal-11' : 'text-n-ruby-11'"
      >
        {{ t(`SHAWKY.SETTINGS.GATEWAY.${gatewayStatus}`) }}
      </span>
    </div>

    <Dialog
      ref="dialogRef"
      type="alert"
      :title="pendingTitle"
      :description="
        pendingChange
          ? t(`SHAWKY.SETTINGS.SWITCHES.${pendingChange.i18nKey}.CONFIRM`)
          : ''
      "
      :confirm-button-label="t('SHAWKY.SETTINGS.SWITCHES.CONFIRM_BUTTON')"
      @confirm="confirmChange"
    />
  </section>
</template>
