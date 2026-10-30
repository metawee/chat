import { ref } from 'vue';
import ShawkyAPI from 'dashboard/shawky/api/shawky';

// Primary/backup number configuration, fetched once per page load.
const routing = ref({});
let request = null;

export function useShawkyRouting() {
  if (!request) {
    request = ShawkyAPI.getRouting()
      .then(({ data }) => {
        routing.value = data;
      })
      .catch(() => {
        request = null;
      });
  }
  return { routing };
}
