import React, { createContext, useContext, useEffect, useMemo, useState } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { signInWithEmailAndPassword } from 'firebase/auth';

import * as authApi from '../services/authApi';
import { setAuthToken } from '../services/http';
import { getFirebaseAuth, isFirebaseConfigured } from '../config/firebase';

type User = authApi.MeResponse['user'];

type AuthState = {
  isBootstrapping: boolean;
  token: string | null;
  user: User | null;
};

type AuthContextValue = AuthState & {
  login(params: { email: string; password: string }): Promise<void>;
  signup(params: authApi.SignupRequest): Promise<void>;
  logout(): Promise<void>;
};

const TOKEN_KEY = 'auth.token.v1';

const AuthContext = createContext<AuthContextValue | null>(null);

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}

async function persistToken(token: string | null) {
  if (!token) {
    await AsyncStorage.removeItem(TOKEN_KEY);
    return;
  }
  await AsyncStorage.setItem(TOKEN_KEY, token);
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState<AuthState>({
    isBootstrapping: true,
    token: null,
    user: null,
  });

  useEffect(() => {
    let alive = true;

    (async () => {
      try {
        const stored = await AsyncStorage.getItem(TOKEN_KEY);
        if (!alive) return;
        if (stored) {
          setAuthToken(stored);
          try {
            const meRes = await authApi.me();
            if (!alive) return;
            setState({ isBootstrapping: false, token: stored, user: meRes.user });
            return;
          } catch {
            setAuthToken(null);
            await persistToken(null);
          }
        }
        setState({ isBootstrapping: false, token: null, user: null });
      } catch {
        setState({ isBootstrapping: false, token: null, user: null });
      }
    })();

    return () => {
      alive = false;
    };
  }, []);

  const value = useMemo<AuthContextValue>(() => {
    return {
      ...state,
      async login({ email, password }) {
        if (!isFirebaseConfigured) {
          throw new Error(
            'Firebase is not configured. Set EXPO_PUBLIC_FIREBASE_* env vars in frontend before logging in.'
          );
        }
        const auth = getFirebaseAuth();
        if (!auth) throw new Error('Firebase auth init failed');

        const cred = await signInWithEmailAndPassword(auth, email, password);
        const token = await cred.user.getIdToken();

        setAuthToken(token);
        await persistToken(token);

        const meRes = await authApi.me();
        setState({ isBootstrapping: false, token, user: meRes.user });
      },
      async signup(params) {
        await authApi.signup(params);
        await this.login({ email: params.email, password: params.password });
      },
      async logout() {
        setAuthToken(null);
        await persistToken(null);
        setState({ isBootstrapping: false, token: null, user: null });
      },
    };
  }, [state]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

