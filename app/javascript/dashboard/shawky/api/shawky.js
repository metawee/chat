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
