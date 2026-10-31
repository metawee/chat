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

  gatewayHealth() {
    return axios.get(`${this.url}/settings/gateway_health`);
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

  addCrmUserMapping({ crmUsername, userId }) {
    return axios.post(`${this.url}/crm_user_mappings`, {
      crm_username: crmUsername,
      user_id: userId,
    });
  }

  removeCrmUserMapping(id) {
    return axios.delete(`${this.url}/crm_user_mappings/${id}`);
  }

  getCrmLaunch() {
    return axios.get(`${this.url}/crm_launch`);
  }

  completeCrmLaunch() {
    return axios.post(`${this.url}/crm_launch`);
  }

  getFollowUps() {
    return axios.get(`${this.url}/follow_ups`);
  }

  getAgentScores() {
    return axios.get(`${this.url}/agent_scores`);
  }

  getDataExports() {
    return axios.get(`${this.url}/data_exports`);
  }

  createDataExport({ fromDate, toDate, fileFormat, includePhoneNumbers }) {
    return axios.post(`${this.url}/data_exports`, {
      from_date: fromDate,
      to_date: toDate,
      file_format: fileFormat,
      include_phone_numbers: includePhoneNumbers,
    });
  }

  getCostReport({ from, to }) {
    return axios.get(`${this.url}/reports/costs`, { params: { from, to } });
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
