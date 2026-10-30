<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { conversationUrl, frontendURL } from 'dashboard/helper/URLHelper';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ShawkyAPI from 'dashboard/shawky/api/shawky';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const errorCode = ref('');

onMounted(async () => {
  try {
    const { data } = await ShawkyAPI.completeCrmLaunch();
    const path = conversationUrl({
      accountId: route.params.accountId,
      id: data.conversation_id,
    });
    router.replace({
      path: frontendURL(path),
      query: data.needs_template ? { shawky_open_templates: 1 } : {},
    });
  } catch (error) {
    errorCode.value = error.response?.data?.error || 'unknown';
  }
});
</script>

<template>
  <div class="flex items-center justify-center w-full h-full p-8">
    <div
      v-if="errorCode"
      class="flex flex-col gap-3 max-w-md p-6 rounded-xl bg-n-solid-2 outline outline-1 outline-n-weak"
    >
      <h2 class="text-heading-2 text-n-slate-12">
        {{ t('SHAWKY.CRM_LAUNCH.ERROR_TITLE') }}
      </h2>
      <p class="text-body-main text-n-slate-11">
        {{ t(`SHAWKY.CRM_LAUNCH.ERRORS.${errorCode.toUpperCase()}`) }}
      </p>
    </div>
    <div v-else class="flex items-center gap-3 text-n-slate-11">
      <Spinner />
      <span class="text-body-main">{{ t('SHAWKY.CRM_LAUNCH.OPENING') }}</span>
    </div>
  </div>
</template>
