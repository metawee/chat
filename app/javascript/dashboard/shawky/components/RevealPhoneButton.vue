<script setup>
import { ref, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useAdmin } from 'dashboard/composables/useAdmin';
import NextButton from 'dashboard/components-next/button/Button.vue';
import ShawkyAPI from 'dashboard/shawky/api/shawky';
import { REVEALED_PHONE_VISIBLE_MS } from 'dashboard/shawky/constants';

const props = defineProps({
  contactId: { type: [Number, String], required: true },
});

const { t } = useI18n();
const { isAdmin } = useAdmin();

const revealedPhone = ref('');
const isLoading = ref(false);
let hideTimer = null;

const reveal = async () => {
  isLoading.value = true;
  try {
    const { data } = await ShawkyAPI.revealPhone(props.contactId);
    revealedPhone.value = data.phone_number;
    clearTimeout(hideTimer);
    hideTimer = setTimeout(() => {
      revealedPhone.value = '';
    }, REVEALED_PHONE_VISIBLE_MS);
  } catch {
    useAlert(t('SHAWKY.REVEAL_PHONE.ERROR'));
  } finally {
    isLoading.value = false;
  }
};

onBeforeUnmount(() => clearTimeout(hideTimer));
</script>

<template>
  <div v-if="isAdmin" class="flex items-center gap-2 ms-6">
    <span
      v-if="revealedPhone"
      dir="ltr"
      class="text-body-main text-n-slate-12 select-all"
    >
      {{ revealedPhone }}
    </span>
    <NextButton
      v-else
      :label="t('SHAWKY.REVEAL_PHONE.BUTTON')"
      :is-loading="isLoading"
      icon="i-lucide-eye"
      xs
      slate
      link
      @click="reveal"
    />
  </div>
</template>
