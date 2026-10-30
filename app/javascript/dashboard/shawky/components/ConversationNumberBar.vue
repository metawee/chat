<script setup>
import { computed, ref, onMounted, onBeforeUnmount } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useStore } from 'dashboard/composables/store';
import { conversationUrl, frontendURL } from 'dashboard/helper/URLHelper';
import NextButton from 'dashboard/components-next/button/Button.vue';
import ShawkyAPI from 'dashboard/shawky/api/shawky';
import { useShawkyRouting } from 'dashboard/shawky/composables/useShawkyRouting';
import {
  WINDOW_TICK_MS,
  WINDOW_WARNING_SECONDS,
} from 'dashboard/shawky/constants';

const props = defineProps({
  chat: { type: Object, required: true },
});

const { t } = useI18n();
const router = useRouter();
const store = useStore();
const { routing } = useShawkyRouting();

const now = ref(Date.now());
let timer = null;
onMounted(() => {
  timer = setInterval(() => {
    now.value = Date.now();
  }, WINDOW_TICK_MS);
});
onBeforeUnmount(() => clearInterval(timer));

const secondsLeft = computed(() => {
  const closesAt = props.chat.shawky_window_closes_at;
  if (!closesAt) return null;
  return Math.max(0, closesAt - Math.floor(now.value / 1000));
});

const windowLabel = computed(() => {
  if (secondsLeft.value === null) return '';
  if (secondsLeft.value === 0) return t('SHAWKY.WINDOW.CLOSED');
  const hours = Math.floor(secondsLeft.value / 3600);
  const minutes = Math.floor((secondsLeft.value % 3600) / 60);
  return t('SHAWKY.WINDOW.REMAINING', { hours, minutes });
});

const windowClass = computed(() => {
  if (secondsLeft.value === 0) return 'bg-n-ruby-3 text-n-ruby-11';
  if (secondsLeft.value < WINDOW_WARNING_SECONDS)
    return 'bg-n-amber-3 text-n-amber-11';
  return 'bg-n-teal-3 text-n-teal-11';
});

const canContinueOnActiveNumber = computed(() => {
  const { active_inbox_id: activeId, primary_inbox_id: primaryId } =
    routing.value;
  const managedInboxes = [primaryId, routing.value.backup_inbox_id];
  return (
    activeId &&
    activeId !== props.chat.inbox_id &&
    managedInboxes.includes(props.chat.inbox_id)
  );
});

const isMoving = ref(false);
const continueOnActiveNumber = async () => {
  isMoving.value = true;
  try {
    const { data } = await ShawkyAPI.continueOnActiveNumber(props.chat.id);
    const path = conversationUrl({
      accountId: store.getters.getCurrentAccountId,
      id: data.id,
    });
    router.push(frontendURL(path));
  } catch {
    useAlert(t('SHAWKY.CONTINUE_ON_ACTIVE_NUMBER.ERROR'));
  } finally {
    isMoving.value = false;
  }
};
</script>

<template>
  <div class="flex items-center gap-2">
    <span
      v-if="windowLabel"
      class="px-2 py-1 rounded-md text-label-small whitespace-nowrap"
      :class="windowClass"
    >
      {{ windowLabel }}
    </span>
    <NextButton
      v-if="canContinueOnActiveNumber"
      :label="t('SHAWKY.CONTINUE_ON_ACTIVE_NUMBER.BUTTON')"
      :is-loading="isMoving"
      icon="i-lucide-repeat"
      xs
      amber
      faded
      @click="continueOnActiveNumber"
    />
  </div>
</template>
