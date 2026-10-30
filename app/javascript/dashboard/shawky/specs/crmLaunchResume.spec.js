import { flushPromises } from '@vue/test-utils';
import { installCrmLaunchResume } from '../crmLaunchResume';
import ShawkyAPI from 'dashboard/shawky/api/shawky';

vi.mock('dashboard/shawky/api/shawky', () => ({
  default: { getCrmLaunch: vi.fn() },
}));

const fakeRouter = () => {
  const hooks = [];
  return {
    afterEach: hook => hooks.push(hook),
    push: vi.fn(),
    navigate: async to => {
      await Promise.all(hooks.map(hook => hook(to)));
      await flushPromises();
    },
  };
};

describe('installCrmLaunchResume', () => {
  beforeEach(() => vi.clearAllMocks());

  it('resumes a pending CRM launch after login, once', async () => {
    ShawkyAPI.getCrmLaunch.mockResolvedValue({ data: { pending: true } });
    const router = fakeRouter();
    installCrmLaunchResume(router);

    await router.navigate({ name: 'home', params: { accountId: '1' } });
    await router.navigate({ name: 'inbox', params: { accountId: '1' } });

    expect(ShawkyAPI.getCrmLaunch).toHaveBeenCalledTimes(1);
    expect(router.push).toHaveBeenCalledWith({
      name: 'shawky_crm_launch',
      params: { accountId: '1' },
    });
  });

  it('does nothing when no launch is waiting', async () => {
    ShawkyAPI.getCrmLaunch.mockResolvedValue({ data: { pending: false } });
    const router = fakeRouter();
    installCrmLaunchResume(router);

    await router.navigate({ name: 'home', params: { accountId: '1' } });

    expect(router.push).not.toHaveBeenCalled();
  });
});
