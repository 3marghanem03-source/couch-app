import React from 'react';
import { DefaultTheme, NavigationContainer } from '@react-navigation/native';
import { ActivityIndicator, View } from 'react-native';

import AuthNavigator from './AuthNavigator';
import { theme } from '../styles/theme';
import { useAuth } from '../context/AuthContext';

const navTheme = {
  ...DefaultTheme,
  colors: {
    ...DefaultTheme.colors,
    background: theme.colors.background,
    card: theme.colors.surface,
    text: theme.colors.text,
    border: theme.colors.border,
    primary: theme.colors.primary,
  },
};

export default function RootNavigator() {
  const { isBootstrapping, token } = useAuth();

  if (isBootstrapping) {
    return (
      <View
        style={{
          flex: 1,
          backgroundColor: theme.colors.background,
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <ActivityIndicator color={theme.colors.primary} />
      </View>
    );
  }

  return (
    <NavigationContainer theme={navTheme}>
      {/* MVP: Auth only. Next: AppNavigator when token exists */}
      <AuthNavigator />
    </NavigationContainer>
  );
}

