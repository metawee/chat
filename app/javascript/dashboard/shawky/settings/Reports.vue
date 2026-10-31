<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import BaseSettingsHeader from 'dashboard/routes/dashboard/settings/components/BaseSettingsHeader.vue';
import SettingsLayout from 'dashboard/routes/dashboard/settings/SettingsLayout.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import ShawkyAPI from 'dashboard/shawky/api/shawky';
import {
  COST_CATEGORIES,
  EXPORT_FORMATS,
  MESSAGE_RATES_EXAMPLE,
} from 'dashboard/shawky/constants';

const { t } = useI18n();

const today = new Date().toISOString().slice(0, 10);
const monthStart = `${today.slice(0, 8)}01`;

const exportFrom = ref(monthStart);
const exportTo = ref(today);
const exportFormat = ref('csv');
const includePhoneNumbers = ref(false);
const exports = ref([]);

const costFrom = ref(monthStart);
const costTo = ref(today);
const costReport = ref(null);
const ratesText = ref('{}');

const usd = amount => `$${amount}`;
const costCell = cell => `${cell.count} (${usd(cell.estimated_cost)})`;

const formatOptions = computed(() =>
  EXPORT_FORMATS.map(format => ({ value: format, label: format.toUpperCase() }))
);

const loadExports = async () => {
  const { data } = await ShawkyAPI.getDataExports();
  exports.value = data;
};

onMounted(async () => {
  await loadExports();
  const { data } = await ShawkyAPI.getSettings();
  ratesText.value = JSON.stringify(data.message_rates || {}, null, 2);
});

const requestExport = async () => {
  try {
    await ShawkyAPI.createDataExport({
      fromDate: exportFrom.value,
      toDate: exportTo.value,
      fileFormat: exportFormat.value,
      includePhoneNumbers: includePhoneNumbers.value,
    });
    useAlert(t('SHAWKY.REPORTS.EXPORT.QUEUED'));
    await loadExports();
  } catch {
    useAlert(t('SHAWKY.SETTINGS.ERROR'));
  }
};

const loadCosts = async () => {
  try {
    const { data } = await ShawkyAPI.getCostReport({
      from: costFrom.value,
      to: costTo.value,
    });
    costReport.value = data;
  } catch {
    useAlert(t('SHAWKY.SETTINGS.ERROR'));
  }
};

const saveRates = async () => {
  try {
    await ShawkyAPI.updateSettings({
      message_rates: JSON.parse(ratesText.value),
    });
    useAlert(t('SHAWKY.SETTINGS.SAVED'));
  } catch {
    useAlert(t('SHAWKY.REPORTS.COSTS.INVALID_RATES'));
  }
};
</script>

<template>
  <SettingsLayout :is-loading="false">
    <template #header>
      <BaseSettingsHeader
        :title="t('SHAWKY.REPORTS.HEADER')"
        :description="t('SHAWKY.REPORTS.DESCRIPTION')"
      />
    </template>
    <template #body>
      <div class="flex flex-col gap-8">
        <section class="flex flex-col gap-3">
          <h3 class="text-heading-3 text-n-slate-12">
            {{ t('SHAWKY.REPORTS.EXPORT.TITLE') }}
          </h3>
          <p class="text-body-main text-n-slate-11">
            {{ t('SHAWKY.REPORTS.EXPORT.DESCRIPTION') }}
          </p>
          <div class="flex flex-wrap items-center gap-2">
            <Input v-model="exportFrom" type="date" />
            <Input v-model="exportTo" type="date" />
            <Select v-model="exportFormat" :options="formatOptions" />
            <label class="flex items-center gap-2 text-body-main">
              <Switch v-model="includePhoneNumbers" />
              {{ t('SHAWKY.REPORTS.EXPORT.INCLUDE_PHONES') }}
            </label>
            <NextButton
              :label="t('SHAWKY.REPORTS.EXPORT.BUTTON')"
              sm
              @click="requestExport"
            />
          </div>
          <div
            v-if="exports.length"
            class="divide-y divide-n-weak border-t border-n-weak"
          >
            <div
              v-for="item in exports"
              :key="item.id"
              class="flex items-center justify-between gap-4 py-2 text-body-main"
            >
              <span>
                {{
                  t('SHAWKY.REPORTS.EXPORT.RANGE', {
                    from: item.from_date,
                    to: item.to_date,
                  })
                }}
                · {{ item.file_format.toUpperCase() }}
                <template v-if="item.include_phone_numbers">
                  · {{ t('SHAWKY.REPORTS.EXPORT.WITH_PHONES') }}
                </template>
              </span>
              <a
                v-if="item.download_url"
                :href="item.download_url"
                class="text-n-blue-11"
              >
                {{ t('SHAWKY.REPORTS.EXPORT.DOWNLOAD') }}
              </a>
              <span v-else class="text-n-slate-11">
                {{
                  t(`SHAWKY.REPORTS.EXPORT.STATUS.${item.status.toUpperCase()}`)
                }}
              </span>
            </div>
          </div>
        </section>

        <section class="flex flex-col gap-3">
          <h3 class="text-heading-3 text-n-slate-12">
            {{ t('SHAWKY.REPORTS.COSTS.TITLE') }}
          </h3>
          <p class="text-body-main text-n-slate-11">
            {{ t('SHAWKY.REPORTS.COSTS.DESCRIPTION') }}
          </p>
          <div class="flex flex-wrap items-center gap-2">
            <Input v-model="costFrom" type="date" />
            <Input v-model="costTo" type="date" />
            <NextButton
              :label="t('SHAWKY.REPORTS.COSTS.BUTTON')"
              sm
              @click="loadCosts"
            />
          </div>
          <template v-if="costReport">
            <p
              v-if="!costReport.rates_configured"
              class="text-body-main text-n-amber-11"
            >
              {{ t('SHAWKY.REPORTS.COSTS.NO_RATES') }}
            </p>
            <div
              v-for="group in ['numbers', 'agents']"
              :key="group"
              class="flex flex-col gap-2"
            >
              <h4 class="text-heading-4 text-n-slate-12">
                {{ t(`SHAWKY.REPORTS.COSTS.${group.toUpperCase()}`) }}
              </h4>
              <table class="w-full text-body-main text-start">
                <thead class="text-n-slate-11">
                  <tr>
                    <th class="py-1 text-start">
                      {{ t('SHAWKY.REPORTS.COSTS.NAME') }}
                    </th>
                    <th
                      v-for="category in COST_CATEGORIES"
                      :key="category"
                      class="py-1 text-start"
                    >
                      {{
                        t(
                          `SHAWKY.REPORTS.COSTS.CATEGORIES.${category.toUpperCase()}`
                        )
                      }}
                    </th>
                    <th class="py-1 text-start">
                      {{ t('SHAWKY.REPORTS.COSTS.TOTAL') }}
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <tr
                    v-for="row in costReport[group]"
                    :key="row.id || 'none'"
                    class="border-t border-n-weak"
                  >
                    <td class="py-1">
                      {{ row.name || t('SHAWKY.REPORTS.COSTS.SYSTEM') }}
                    </td>
                    <td
                      v-for="category in COST_CATEGORIES"
                      :key="category"
                      class="py-1"
                    >
                      {{ costCell(row.categories[category]) }}
                    </td>
                    <td class="py-1">{{ usd(row.estimated_cost) }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </template>
          <p class="text-body-main text-n-slate-11">
            {{ t('SHAWKY.REPORTS.COSTS.RATES_HELP') }}
          </p>
          <code dir="ltr" class="text-label-small text-n-slate-11">
            {{ MESSAGE_RATES_EXAMPLE }}
          </code>
          <TextArea v-model="ratesText" dir="ltr" class="font-mono" />
          <NextButton
            :label="t('SHAWKY.SETTINGS.SAVE')"
            sm
            class="self-start"
            @click="saveRates"
          />
        </section>
      </div>
    </template>
  </SettingsLayout>
</template>
