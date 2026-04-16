import React, { useState } from 'react';
import { Alert, Pressable, StyleSheet, Text, View } from 'react-native';
import { NativeStackScreenProps } from '@react-navigation/native-stack';

import Screen from '../components/Screen';
import AppTextInput from '../components/AppTextInput';
import AppButton from '../components/AppButton';
import { theme } from '../styles/theme';
import { AuthStackParamList } from '../navigation/AuthNavigator';
import { useAuth } from '../context/AuthContext';
import { getApiErrorMessage } from '../utils/apiError';

type Props = NativeStackScreenProps<AuthStackParamList, 'Login'>;

export default function LoginScreen({ navigation }: Props) {
  const { login } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);

  async function onSubmit() {
    try {
      setLoading(true);
      await login({ email: email.trim(), password });
      Alert.alert('Logged in', 'Success.');
    } catch (e: unknown) {
      Alert.alert('Login failed', getApiErrorMessage(e, 'Unknown error'));
    } finally {
      setLoading(false);
    }
  }

  return (
    <Screen>
      <View style={{ gap: 8 }}>
        <Text style={styles.title}>Welcome back</Text>
        <Text style={styles.subtitle}>Login to manage bookings and schedules.</Text>
      </View>

      <AppTextInput
        label="Email"
        value={email}
        onChangeText={setEmail}
        autoCapitalize="none"
        keyboardType="email-address"
      />
      <AppTextInput
        label="Password"
        value={password}
        onChangeText={setPassword}
        secureTextEntry
      />

      <AppButton title="Login" onPress={onSubmit} loading={loading} />

      <Pressable onPress={() => navigation.navigate('Signup')}>
        <Text style={styles.link}>
          Don’t have an account? <Text style={styles.linkStrong}>Sign up</Text>
        </Text>
      </Pressable>
    </Screen>
  );
}

const styles = StyleSheet.create({
  title: { color: theme.colors.text, fontSize: theme.typography.h1, fontWeight: '900' },
  subtitle: { color: theme.colors.mutedText, fontSize: theme.typography.body, marginTop: 6 },
  link: { color: theme.colors.mutedText, textAlign: 'center', marginTop: theme.spacing.sm },
  linkStrong: { color: theme.colors.primary, fontWeight: '800' },
});

