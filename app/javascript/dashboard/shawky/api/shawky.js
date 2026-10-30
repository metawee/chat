/* global axios */
import ApiClient from 'dashboard/api/ApiClient';

class ShawkyAPI extends ApiClient {
  constructor() {
    super('shawky', { accountScoped: true });
  }

  revealPhone(contactId) {
    return axios.get(`${this.url}/contacts/${contactId}/phone`);
  }

  getSettings() {
    return axios.get(`${this.url}/settings`);
  }

  updateSettings(settings) {
    return axios.patch(`${this.url}/settings`, settings);
  }

  getRouting() {
    return axios.get(`${this.url}/routing`);
  }

  failback() {
    return axios.post(`${this.url}/settings/failback`);
  }

  continueOnActiveNumber(conversationId) {
    return axios.post(
      `${this.url}/conversations/${conversationId}/continue_on_active_number`
    );
  }

  getCrmUserMappings() {
    return axios.get(`${this.url}/crm_user_mappings`);
  }

  addCrmUserMapping({ crmUserId, userId }) {
    return axios.post(`${this.url}/crm_user_mappings`, {
      crm_user_id: crmUserId,
      user_id: userId,
    });
  }

  removeCrmUserMapping(id) {
    return axios.delete(`${this.url}/crm_user_mappings/${id}`);
  }

  getTeamSupervisors() {
    return axios.get(`${this.url}/team_supervisors`);
  }

  addTeamSupervisor({ teamId, userId }) {
    return axios.post(`${this.url}/team_supervisors`, {
      team_id: teamId,
      user_id: userId,
    });
  }

  removeTeamSupervisor(id) {
    return axios.delete(`${this.url}/team_supervisors/${id}`);
  }
}

export default new ShawkyAPI();
