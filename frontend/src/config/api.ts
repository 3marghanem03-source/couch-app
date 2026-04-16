import Constants from 'expo-constants';
import { Platform } from 'react-native';

function guessDevApiBaseUrl() {
  // Android emulator cannot reach host "localhost"; it uses 10.0.2.2 instead.
  if (Platform.OS === 'android') return 'http://10.0.2.2:4000';

  // For iOS simulator and web, localhost usually works.
  if (Platform.OS === 'ios' || Platform.OS === 'web') return 'http://localhost:4000';

  // For physical devices in Expo dev, try to infer the host machine IP from Expo hostUri.
  const hostUri =
    Constants.expoConfig?.hostUri ||
    // Older/alternate fields depending on Expo runtime.
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (Constants as any)?.expoGoConfig?.debuggerHost ||
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (Constants as any)?.manifest2?.extra?.expoGo?.debuggerHost ||
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    (Constants as any)?.manifest?.debuggerHost ||
    '';

  // hostUri/debuggerHost often looks like: "192.168.1.10:19000"
  const host = String(hostUri).split('/')[0];
  const ip = host.split(':')[0];
  if (ip && ip !== 'localhost') return `http://${ip}:4000`;

  return 'http://localhost:4000';
}

export const API_BASE_URL = process.env.EXPO_PUBLIC_API_BASE_URL?.trim() || guessDevApiBaseUrl();

