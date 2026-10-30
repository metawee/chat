<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import BaseSettingsHeader from 'dashboard/routes/dashboard/settings/components/BaseSettingsHeader.vue';
import SettingsLayout from 'dashboard/routes/dashboard/settings/SettingsLayout.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import ShawkyAPI from 'dashboard/shawky/api/shawky';
import { PHONE_MASK_MODES } from 'dashboard/shawky/constants';

const { t } = useI18n();
const store = useStore();

const teams = useMapGetter('teams/getTeams');
const agents = useMapGetter('agents/getAgents');

const isLoading = ref(true);
const phoneMaskMode = ref('last3');
const supervisors = ref([]);
const newTeamId = ref('');
const newUserId = ref('');

const maskModeOptions = computed(() =>
  PHONE_MASK_MODES.map(mode => ({
    value: mode,
    label: t(`SHAWKY.SETTINGS.MASK_MODE.OPTIONS.${mode.toUpperCase()}`),
  }))
);
const teamOptions = computed(() =>
  teams.value.map(team => ({ value: team.id, label: team.name }))
);
const agentOptions = computed(() =>
  agents.value.map(agent => ({ value: agent.id, label: agent.name }))
);

const nameOf = (list, id) => list.value.find(item => item.id === id)?.name;
const supervisorRows = computed(() =>
  supervisors.value.map(supervisor => ({
    ...supervisor,
    teamName: nameOf(teams, supervisor.team_id),
    userName: nameOf(agents, supervisor.user_id),
  }))
);

const loadSupervisors = async () => {
  const { data } = await ShawkyAPI.getTeamSupervisors();
  supervisors.value = data;
};

onMounted(async () => {
  try {
    await Promise.all([
      store.dispatch('teams/get'),
      store.dispatch('agents/get'),
      loadSupervisors(),
      ShawkyAPI.getSettings().then(({ data }) => {
        phoneMaskMode.value = data.phone_mask_mode;
      }),
    ]);
  } finally {
    isLoading.value = false;
  }
});

const saveMaskMode = async mode => {
  try {
    await ShawkyAPI.updateSettings({ phone_mask_mode: mode });
    phoneMaskMode.value = mode;
    useAlert(t('SHAWKY.SETTINGS.SAVED'));
  } catch {
    useAlert(t('SHAWKY.SETTINGS.ERROR'));
  }
};

const addSupervisor = async () => {
  try {
    await ShawkyAPI.addTeamSupervisor({
      teamId: newTeamId.value,
      userId: newUserId.value,
    });
    newTeamId.value = '';
    newUserId.value = '';
    await loadSupervisors();
    useAlert(t('SHAWKY.SETTINGS.SAVED'));
  } catch {
    useAlert(t('SHAWKY.SETTINGS.ERROR'));
  }
};

const removeSupervisor = async id => {
  try {
    await ShawkyAPI.removeTeamSupervisor(id);
    await loadSupervisors();
  } catch {
    useAlert(t('SHAWKY.SETTINGS.ERROR'));
  }
};
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="t('SHAWKY.SETTINGS.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('SHAWKY.SETTINGS.HEADER')"
        :description="t('SHAWKY.SETTINGS.DESCRIPTION')"
      />
    </template>
    <template #body>
      <div class="flex flex-col gap-8">
        <section class="flex flex-col gap-3">
          <h3 class="text-heading-3 text-n-slate-12">
            {{ t('SHAWKY.SETTINGS.MASK_MODE.TITLE') }}
          </h3>
          <p class="text-body-main text-n-slate-11">
            {{ t('SHAWKY.SETTINGS.MASK_MODE.DESCRIPTION') }}
          </p>
          <Select
            :model-value="phoneMaskMode"
            :options="maskModeOptions"
            :aria-label="t('SHAWKY.SETTINGS.MASK_MODE.TITLE')"
            @update:model-value="saveMaskMode"
          />
        </section>

        <section class="flex flex-col gap-3">
          <h3 class="text-heading-3 text-n-slate-12">
            {{ t('SHAWKY.SETTINGS.SUPERVISORS.TITLE') }}
          </h3>
          <p class="text-body-main text-n-slate-11">
            {{ t('SHAWKY.SETTINGS.SUPERVISORS.DESCRIPTION') }}
          </p>
          <div class="flex flex-wrap items-center gap-2">
            <Select
              v-model="newTeamId"
              :options="teamOptions"
              :placeholder="t('SHAWKY.SETTINGS.SUPERVISORS.TEAM')"
            />
            <Select
              v-model="newUserId"
              :options="agentOptions"
              :placeholder="t('SHAWKY.SETTINGS.SUPERVISORS.USER')"
            />
            <NextButton
              :label="t('SHAWKY.SETTINGS.SUPERVISORS.ADD')"
              :disabled="!newTeamId || !newUserId"
              sm
              @click="addSupervisor"
            />
          </div>
          <p
            v-if="!supervisorRows.length"
            class="text-body-main text-n-slate-11"
          >
            {{ t('SHAWKY.SETTINGS.SUPERVISORS.EMPTY') }}
          </p>
          <div v-else class="divide-y divide-n-weak border-t border-n-weak">
            <div
              v-for="row in supervisorRows"
              :key="row.id"
              class="flex items-center justify-between gap-4 py-3"
            >
              <span class="text-body-main text-n-slate-12">
                {{ row.userName }} — {{ row.teamName }}
              </span>
              <NextButton
                :label="t('SHAWKY.SETTINGS.SUPERVISORS.REMOVE')"
                xs
                ruby
                faded
                @click="removeSupervisor(row.id)"
              />
            </div>
          </div>
        </section>
      </div>
    </template>
  </SettingsLayout>
</template>
