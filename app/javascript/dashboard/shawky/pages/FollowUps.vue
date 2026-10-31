<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { dynamicTime } from 'shared/helpers/timeHelper';
import { conversationUrl, frontendURL } from 'dashboard/helper/URLHelper';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ShawkyAPI from 'dashboard/shawky/api/shawky';

const { t } = useI18n();
const route = useRoute();
const followUps = ref([]);
const isLoading = ref(true);

const linkTo = id =>
  frontendURL(conversationUrl({ accountId: route.params.accountId, id }));

onMounted(async () => {
  try {
    const { data } = await ShawkyAPI.getFollowUps();
    followUps.value = data.payload;
  } finally {
    isLoading.value = false;
  }
});
</script>

<template>
  <div class="flex flex-col w-full h-full gap-4 p-6 overflow-y-auto">
    <div class="flex flex-col gap-1">
      <h1 class="text-heading-1 text-n-slate-12">
        {{ t('SHAWKY.FOLLOW_UPS.HEADER') }}
      </h1>
      <p class="text-body-main text-n-slate-11">
        {{ t('SHAWKY.FOLLOW_UPS.DESCRIPTION') }}
      </p>
    </div>
    <Spinner v-if="isLoading" />
    <p v-else-if="!followUps.length" class="text-body-main text-n-slate-11">
      {{ t('SHAWKY.FOLLOW_UPS.EMPTY') }}
    </p>
    <div v-else class="divide-y divide-n-weak border-y border-n-weak">
      <router-link
        v-for="item in followUps"
        :key="item.id"
        :to="linkTo(item.id)"
        class="flex flex-wrap items-center justify-between gap-3 py-3 hover:bg-n-alpha-1"
      >
        <div class="flex flex-col">
          <span class="text-body-main text-n-slate-12">
            {{ item.contact_name }}
          </span>
          <span class="text-label-small text-n-slate-11">
            #{{ item.id }}
            <template v-if="item.lead_id">· {{ item.lead_id }}</template>
            <template v-if="item.assignee">· {{ item.assignee.name }}</template>
          </span>
        </div>
        <span class="text-label-small text-n-slate-11">
          {{
            item.last_agent_message_at
              ? t('SHAWKY.FOLLOW_UPS.LAST_AGENT_MESSAGE', {
                  time: dynamicTime(item.last_agent_message_at),
                })
              : t('SHAWKY.FOLLOW_UPS.NO_AGENT_MESSAGE')
          }}
        </span>
      </router-link>
    </div>
  </div>
</template>
