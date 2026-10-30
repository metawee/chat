import ShawkyAPI from 'dashboard/shawky/api/shawky';

// GET /chat parks a CRM launch server-side. When the agent had to log in first, the
// dashboard lands on its home page instead, so ask once per page load and resume.
export function installCrmLaunchResume(router) {
  let checked = false;
  router.afterEach(async to => {
    if (checked || !to.params.accountId) return;
    checked = true;
    if (to.name === 'shawky_crm_launch') return;

    try {
      const { data } = await ShawkyAPI.getCrmLaunch();
      if (data.pending) {
        router.push({
          name: 'shawky_crm_launch',
          params: { accountId: to.params.accountId },
        });
      }
    } catch {
      // Nothing to resume.
    }
  });
}
