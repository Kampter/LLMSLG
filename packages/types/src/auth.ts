/**
 * Authentication request/response types — mirrors
 * `python-packages/shared/src/shared/models/auth.py`.
 */

export interface RegisterRequest {
  username: string;
  password: string;
  email?: string;
}

export interface LoginRequest {
  username: string;
  password: string;
}

export interface TokenResponse {
  access_token: string;
  token_type: 'bearer';
  expires_in: number;
}

export interface RefreshRequest {
  refresh_token: string;
}
