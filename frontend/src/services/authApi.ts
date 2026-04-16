import { http } from './http';

export type Role = 'coach' | 'client';

export type SignupRequest = {
  email: string;
  password: string;
  role: Role;
  displayName?: string;
};

export type SignupResponse = {
  uid: string;
  role: Role;
};

export type MeResponse = {
  user: {
    uid: string;
    role: Role;
    email?: string;
    displayName?: string | null;
  };
};

export async function signup(req: SignupRequest) {
  const { data } = await http.post<SignupResponse>('/api/auth/signup', req);
  return data;
}

export async function me() {
  const { data } = await http.get<MeResponse>('/api/auth/me');
  return data;
}

