import { OpenFgaApi, OpenFgaClient } from '@openfga/sdk';

export class OpenFGAService {
  private client: OpenFgaClient;
  private storeId: string;
  private authModelId: string;

  constructor() {
    const apiUrl = process.env.OPENFGA_API_URL || 'http://localhost:8080';
    this.storeId = process.env.OPENFGA_STORE_ID || '';
    this.authModelId = process.env.OPENFGA_AUTH_MODEL_ID || '';

    this.client = new OpenFgaClient({
      apiUrl,
      storeId: this.storeId
    });
  }

  /**
   * Check if a user has permission to perform an action on a resource
   */
  async check(user: string, relation: string, object: string): Promise<boolean> {
    try {
      const response = await this.client.check({
        user,
        relation,
        object,
        authorization_model_id: this.authModelId
      });

      return response.allowed || false;
    } catch (error) {
      console.error('OpenFGA check failed:', error);
      return false;
    }
  }

  /**
   * List objects that a user has a specific relation with
   */
  async listObjects(user: string, relation: string, type: string): Promise<string[]> {
    try {
      const response = await this.client.listObjects({
        user,
        relation,
        type,
        authorization_model_id: this.authModelId
      });

      return response.objects || [];
    } catch (error) {
      console.error('OpenFGA listObjects failed:', error);
      return [];
    }
  }

  /**
   * Write relationship tuples to establish permissions
   */
  async writeTuples(tuples: Array<{ user: string; relation: string; object: string }>): Promise<boolean> {
    try {
      await this.client.write({
        writes: tuples.map(tuple => ({
          user: tuple.user,
          relation: tuple.relation,
          object: tuple.object
        })),
        authorization_model_id: this.authModelId
      });

      return true;
    } catch (error) {
      console.error('OpenFGA write failed:', error);
      return false;
    }
  }

  /**
   * Delete relationship tuples
   */
  async deleteTuples(tuples: Array<{ user: string; relation: string; object: string }>): Promise<boolean> {
    try {
      await this.client.write({
        deletes: tuples.map(tuple => ({
          user: tuple.user,
          relation: tuple.relation,
          object: tuple.object
        })),
        authorization_model_id: this.authModelId
      });

      return true;
    } catch (error) {
      console.error('OpenFGA delete failed:', error);
      return false;
    }
  }

  /**
   * Create a new store (used during setup)
   */
  async createStore(name: string): Promise<string | null> {
    try {
      const response = await this.client.createStore({
        name
      });

      return response.id || null;
    } catch (error) {
      console.error('OpenFGA createStore failed:', error);
      return null;
    }
  }

  /**
   * Write authorization model (used during setup)
   */
  async writeAuthorizationModel(model: any): Promise<string | null> {
    try {
      const response = await this.client.writeAuthorizationModel(model);
      return response.authorization_model_id || null;
    } catch (error) {
      console.error('OpenFGA writeAuthorizationModel failed:', error);
      return null;
    }
  }

  /**
   * Helper method to format user identifier
   */
  static formatUser(userId: string, userType: string = 'user'): string {
    return `${userType}:${userId}`;
  }

  /**
   * Helper method to format object identifier
   */
  static formatObject(objectId: string, objectType: string): string {
    return `${objectType}:${objectId}`;
  }
}

export const openFGAService = new OpenFGAService();