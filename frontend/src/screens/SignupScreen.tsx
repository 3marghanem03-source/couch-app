import React, { useMemo, useState } from 'react';
import { Alert, Pressable, StyleSheet, Text, View } from 'react-native';
import { NativeStackScreenProps } from '@react-navigation/native-stack';

import Screen from '../components/Screen';
import AppTextInput from '../components/AppTextInput';
import AppButton from '../components/AppButton';
import { theme } from '../styles/theme';
import { AuthStackParamList } from '../navigation/AuthNavigator';
import { useAuth } from '../context/AuthContext';
import type { Role } from '../services/authApi';
import { getApiErrorMessage } from '../utils/apiError';

type Props = NativeStackScreenProps<AuthStackParamList, 'Signup'>;

function RolePill({
  label,
  active,
  onPress,
}: {
  label: string;
  active: boolean;
  onPress: () => void;
}) {
  return (
    <Pressable
      onPress={onPress}
      style={[
        styles.pill,
        { borderColor: active ? theme.colors.primary : theme.colors.border },
        active ? { backgroundColor: theme.colors.surface2 } : null,
      ]}
    >
      <Text style={[styles.pillText, active ? { color: theme.colors.text } : null]}>{label}</Text>
    </Pressable>
  );
}

export default function SignupScreen({ navigation }: Props) {
  const { signup } = useAuth();
  const [displayName, setDisplayName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [role, setRole] = useState<Role>('client');
  const [loading, setLoading] = useState(false);

  const roleHint = useMemo(() => {
    return role === 'coach'
      ? 'Coach can create weekly availability and approve bookings.'
      : 'Client can view public schedule and request bookings.';
  }, [role]);

  async function onSubmit() {
    try {
      setLoading(true);
      await signup({
        email: email.trim(),
        password,
        role,
        displayName: displayName.trim() || undefined,
      });
      Alert.alert('Account created', 'You are now logged in.');
    } catch (e: unknown) {
      Alert.alert('Signup failed', getApiErrorMessage(e, 'Unknown error'));
    } finally {
      setLoading(false);
    }
  }

  return (
    <Screen>
      <View style={{ gap: 8 }}>
        <Text style={styles.title}>Create account</Text>
        <Text style={styles.subtitle}>Choose your role and get started.</Text>
      </View>

      <View style={{ gap: 10 }}>
        <Text style={styles.sectionLabel}>Role</Text>
        <View style={styles.pillRow}>
          <RolePill label="Client" active={role === 'client'} onPress={() => setRole('client')} />
          <RolePill label="Coach" active={role === 'coach'} onPress={() => setRole('coach')} />
        </View>
        <Text style={styles.hint}>{roleHint}</Text>
      </View>

      <AppTextInput label="Display name (optional)" value={displayName} onChangeText={setDisplayName} />
      <AppTextInput
        label="Email"
        value={email}
        onChangeText={setEmail}
        autoCapitalize="none"
        keyboardType="email-address"
      />
      <AppTextInput label="Password (min 6)" value={password} onChangeText={setPassword} secureTextEntry />

      <AppButton title="Sign up" onPress={onSubmit} loading={loading} />

      <Pressable onPress={() => navigation.navigate('Login')}>
        <Text style={styles.link}>
          Already have an account? <Text style={styles.linkStrong}>Login</Text>
        </Text>
      </Pressable>
    </Screen>
  );
}

const styles = StyleSheet.create({
  title: { color: theme.colors.text, fontSize: theme.typography.h1, fontWeight: '900' },
  subtitle: { color: theme.colors.mutedText, fontSize: theme.typography.body, marginTop: 6 },
  sectionLabel: { color: theme.colors.mutedText, fontSize: theme.typography.small, fontWeight: '700' },
  pillRow: { flexDirection: 'row', gap: 12 },
  pill: {
    flex: 1,
    paddingVertical: 12,
    borderRadius: theme.radius.md,
    borderWidth: 1,
    backgroundColor: theme.colors.surface,
    alignItems: 'center',
  },
  pillText: { color: theme.colors.mutedText, fontWeight: '800' },
  hint: { color: theme.colors.mutedText, fontSize: theme.typography.small, marginTop: 4 },
  link: { color: theme.colors.mutedText, textAlign: 'center', marginTop: theme.spacing.sm },
  linkStrong: { color: theme.colors.primary, fontWeight: '800' },
});

