<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import BaseSettingsHeader from 'dashboard/routes/dashboard/settings/components/BaseSettingsHeader.vue';
import SettingsLayout from 'dashboard/routes/dashboard/settings/SettingsLayout.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import ShawkyAPI from 'dashboard/shawky/api/shawky';
import { PHONE_MASK_MODES } from 'dashboard/shawky/constants';

const { t } = useI18n();
const store = useStore();

const teams = useMapGetter('teams/getTeams');
const agents = useMapGetter('agents/getAgents');
const inboxes = useMapGetter('inboxes/getInboxes');

const isLoading = ref(true);
const phoneMaskMode = ref('last3');
const supervisors = ref([]);
const newTeamId = ref('');
const newUserId = ref('');
const routing = ref({});
const welcomeMessage = ref('');
const crmOwnerWaitSeconds = ref(60);
const replyDelayMinutes = ref(120);
const autoReassignOnDelay = ref(false);
const followUpDays = ref(3);
const crmMappings = ref([]);
const newCrmUserId = ref('');
const newCrmMappedUserId = ref('');

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

const whatsappInboxOptions = computed(() =>
  inboxes.value
    .filter(inbox => inbox.channel_type === 'Channel::Whatsapp')
    .map(inbox => ({ value: inbox.id, label: inbox.name }))
);
const isOnBackup = computed(
  () =>
    routing.value.backup_inbox_id &&
    routing.value.active_inbox_id === routing.value.backup_inbox_id
);

const nameOf = (list, id) => list.value.find(item => item.id === id)?.name;
const supervisorRows = computed(() =>
  supervisors.value.map(supervisor => ({
    ...supervisor,
    teamName: nameOf(teams, supervisor.team_id),
    userName: nameOf(agents, supervisor.user_id),
  }))
);

const crmMappingRows = computed(() =>
  crmMappings.value.map(mapping => ({
    ...mapping,
    userName: nameOf(agents, mapping.user_id),
  }))
);

const applySettings = data => {
  phoneMaskMode.value = data.phone_mask_mode;
  routing.value = data;
  welcomeMessage.value = data.welcome_message || '';
  crmOwnerWaitSeconds.value = data.crm_owner_wait_seconds;
  replyDelayMinutes.value = data.reply_delay_minutes;
  autoReassignOnDelay.value = data.auto_reassign_on_delay;
  followUpDays.value = data.follow_up_days;
};

const loadCrmMappings = async () => {
  const { data } = await ShawkyAPI.getCrmUserMappings();
  crmMappings.value = data;
};

const loadSupervisors = async () => {
  const { data } = await ShawkyAPI.getTeamSupervisors();
  supervisors.value = data;
};

onMounted(async () => {
  try {
    await Promise.all([
      store.dispatch('teams/get'),
      store.dispatch('agents/get'),
      store.dispatch('inboxes/get'),
      loadSupervisors(),
      loadCrmMappings(),
      ShawkyAPI.getSettings().then(({ data }) => applySettings(data)),
    ]);
  } finally {
    isLoading.value = false;
  }
});

const saveSettings = async changes => {
  try {
    const { data } = await ShawkyAPI.updateSettings(changes);
    applySettings(data);
    useAlert(t('SHAWKY.SETTINGS.SAVED'));
  } catch {
    useAlert(t('SHAWKY.SETTINGS.ERROR'));
  }
};

const failback = async () => {
  try {
    const { data } = await ShawkyAPI.failback();
    applySettings(data);
    useAlert(t('SHAWKY.SETTINGS.SAVED'));
  } catch {
    useAlert(t('SHAWKY.SETTINGS.ERROR'));
  }
};

const addCrmMapping = async () => {
  try {
    await ShawkyAPI.addCrmUserMapping({
      crmUsername: newCrmUserId.value.trim(),
      userId: newCrmMappedUserId.value,
    });
    newCrmUserId.value = '';
    newCrmMappedUserId.value = '';
    await loadCrmMappings();
  } catch {
    useAlert(t('SHAWKY.SETTINGS.ERROR'));
  }
};

const removeCrmMapping = async id => {
  try {
    await ShawkyAPI.removeCrmUserMapping(id);
    await loadCrmMappings();
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
            @update:model-value="
              mode => saveSettings({ phone_mask_mode: mode })
            "
          />
        </section>

        <section class="flex flex-col gap-3">
          <h3 class="text-heading-3 text-n-slate-12">
            {{ t('SHAWKY.SETTINGS.NUMBERS.TITLE') }}
          </h3>
          <p class="text-body-main text-n-slate-11">
            {{ t('SHAWKY.SETTINGS.NUMBERS.DESCRIPTION') }}
          </p>
          <div class="flex flex-wrap items-center gap-2">
            <Select
              :model-value="routing.primary_inbox_id || ''"
              :options="whatsappInboxOptions"
              :placeholder="t('SHAWKY.SETTINGS.NUMBERS.PRIMARY')"
              @update:model-value="id => saveSettings({ primary_inbox_id: id })"
            />
            <Select
              :model-value="routing.backup_inbox_id || ''"
              :options="whatsappInboxOptions"
              :placeholder="t('SHAWKY.SETTINGS.NUMBERS.BACKUP')"
              @update:model-value="id => saveSettings({ backup_inbox_id: id })"
            />
          </div>
          <div v-if="routing.active_inbox_id" class="flex items-center gap-3">
            <span
              class="px-2 py-1 rounded-md text-label-small"
              :class="
                isOnBackup
                  ? 'bg-n-amber-3 text-n-amber-11'
                  : 'bg-n-teal-3 text-n-teal-11'
              "
            >
              {{
                isOnBackup
                  ? t('SHAWKY.SETTINGS.NUMBERS.ON_BACKUP')
                  : t('SHAWKY.SETTINGS.NUMBERS.ON_PRIMARY')
              }}
            </span>
            <NextButton
              v-if="isOnBackup"
              :label="t('SHAWKY.SETTINGS.NUMBERS.FAILBACK')"
              sm
              faded
              @click="failback"
            />
          </div>
        </section>

        <section class="flex flex-col gap-3">
          <h3 class="text-heading-3 text-n-slate-12">
            {{ t('SHAWKY.SETTINGS.WELCOME.TITLE') }}
          </h3>
          <p class="text-body-main text-n-slate-11">
            {{ t('SHAWKY.SETTINGS.WELCOME.DESCRIPTION') }}
          </p>
          <TextArea
            v-model="welcomeMessage"
            :placeholder="t('SHAWKY.SETTINGS.WELCOME.PLACEHOLDER')"
          />
          <div class="flex flex-wrap items-center gap-2">
            <span class="text-body-main text-n-slate-11">
              {{ t('SHAWKY.SETTINGS.WELCOME.CRM_WAIT') }}
            </span>
            <Input
              v-model="crmOwnerWaitSeconds"
              type="number"
              min="10"
              class="w-24"
            />
            <NextButton
              :label="t('SHAWKY.SETTINGS.SAVE')"
              sm
              @click="
                saveSettings({
                  welcome_message: welcomeMessage,
                  crm_owner_wait_seconds: crmOwnerWaitSeconds,
                })
              "
            />
          </div>
        </section>

        <section class="flex flex-col gap-3">
          <h3 class="text-heading-3 text-n-slate-12">
            {{ t('SHAWKY.SETTINGS.SLA.TITLE') }}
          </h3>
          <div class="flex flex-wrap items-center gap-2">
            <span class="text-body-main text-n-slate-11">
              {{ t('SHAWKY.SETTINGS.SLA.REPLY_DELAY') }}
            </span>
            <Input
              v-model="replyDelayMinutes"
              type="number"
              min="5"
              class="w-24"
            />
          </div>
          <label class="flex items-center gap-2 text-body-main">
            <Switch v-model="autoReassignOnDelay" />
            {{ t('SHAWKY.SETTINGS.SLA.AUTO_REASSIGN') }}
          </label>
          <div class="flex flex-wrap items-center gap-2">
            <span class="text-body-main text-n-slate-11">
              {{ t('SHAWKY.SETTINGS.SLA.FOLLOW_UP_DAYS') }}
            </span>
            <Input v-model="followUpDays" type="number" min="1" class="w-24" />
            <NextButton
              :label="t('SHAWKY.SETTINGS.SAVE')"
              sm
              @click="
                saveSettings({
                  reply_delay_minutes: replyDelayMinutes,
                  auto_reassign_on_delay: autoReassignOnDelay,
                  follow_up_days: followUpDays,
                })
              "
            />
          </div>
        </section>

        <section class="flex flex-col gap-3">
          <h3 class="text-heading-3 text-n-slate-12">
            {{ t('SHAWKY.SETTINGS.CRM_USERS.TITLE') }}
          </h3>
          <p class="text-body-main text-n-slate-11">
            {{ t('SHAWKY.SETTINGS.CRM_USERS.DESCRIPTION') }}
          </p>
          <div class="flex flex-wrap items-center gap-2">
            <Input
              v-model="newCrmUserId"
              :placeholder="t('SHAWKY.SETTINGS.CRM_USERS.CRM_ID')"
              class="w-40"
            />
            <Select
              v-model="newCrmMappedUserId"
              :options="agentOptions"
              :placeholder="t('SHAWKY.SETTINGS.CRM_USERS.USER')"
            />
            <NextButton
              :label="t('SHAWKY.SETTINGS.CRM_USERS.ADD')"
              :disabled="!newCrmUserId.trim() || !newCrmMappedUserId"
              sm
              @click="addCrmMapping"
            />
          </div>
          <div
            v-if="crmMappingRows.length"
            class="divide-y divide-n-weak border-t border-n-weak"
          >
            <div
              v-for="row in crmMappingRows"
              :key="row.id"
              class="flex items-center justify-between gap-4 py-3"
            >
              <span class="text-body-main text-n-slate-12">
                {{ row.crm_username }} — {{ row.userName }}
              </span>
              <NextButton
                :label="t('SHAWKY.SETTINGS.SUPERVISORS.REMOVE')"
                xs
                ruby
                faded
                @click="removeCrmMapping(row.id)"
              />
            </div>
          </div>
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
