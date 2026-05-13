/**
 * User and profile types — mirrors
 * `python-packages/shared/src/shared/models/user.py`.
 */

export type UserId = string;

export interface User {
  user_id: UserId;
  username: string;
  email?: string;
  display_name?: string;
  created_at: string;
  updated_at: string;
}

export interface UserProfile {
  display_name?: string;
  avatar?: string;
}
