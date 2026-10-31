<script setup>
import { onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import ShawkyAPI from 'dashboard/shawky/api/shawky';

const { t } = useI18n();
const scores = ref([]);
const isLoading = ref(true);

const COLUMNS = [
  { key: 'average_score', label: 'SHAWKY.AGENT_SCORES.AVERAGE' },
  { key: 'reviewed_count', label: 'SHAWKY.AGENT_SCORES.REVIEWED' },
  { key: 'flagged_count', label: 'SHAWKY.AGENT_SCORES.FLAGGED' },
  { key: 'abuse_count', label: 'SHAWKY.AGENT_SCORES.ABUSE' },
];

onMounted(async () => {
  try {
    const { data } = await ShawkyAPI.getAgentScores();
    scores.value = data.payload;
  } finally {
    isLoading.value = false;
  }
});
</script>

<template>
  <div class="flex flex-col w-full h-full gap-4 p-6 overflow-y-auto">
    <div class="flex flex-col gap-1">
      <h1 class="text-heading-1 text-n-slate-12">
        {{ t('SHAWKY.AGENT_SCORES.HEADER') }}
      </h1>
      <p class="text-body-main text-n-slate-11">
        {{ t('SHAWKY.AGENT_SCORES.DESCRIPTION') }}
      </p>
    </div>
    <Spinner v-if="isLoading" />
    <p v-else-if="!scores.length" class="text-body-main text-n-slate-11">
      {{ t('SHAWKY.AGENT_SCORES.EMPTY') }}
    </p>
    <table v-else class="w-full text-start text-body-main">
      <thead class="text-label-small text-n-slate-11 border-b border-n-weak">
        <tr>
          <th class="py-2 text-start">{{ t('SHAWKY.AGENT_SCORES.AGENT') }}</th>
          <th v-for="column in COLUMNS" :key="column.key" class="py-2 text-start">
            {{ t(column.label) }}
          </th>
        </tr>
      </thead>
      <tbody class="divide-y divide-n-weak">
        <tr v-for="row in scores" :key="row.user_id" class="text-n-slate-12">
          <td class="py-3">{{ row.name }}</td>
          <td v-for="column in COLUMNS" :key="column.key" class="py-3">
            {{ row[column.key] }}
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
