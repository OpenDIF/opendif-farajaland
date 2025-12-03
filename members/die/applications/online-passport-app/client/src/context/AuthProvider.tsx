import { AuthProvider as AsgardeoAuthProvider } from '@asgardeo/auth-react';
import React from 'react';

const authConfig = {
  signInRedirectURL: window.location.origin,
  signOutRedirectURL: window.location.origin,
  clientID: import.meta.env.VITE_ASGARDEO_CLIENT_ID || '',
  baseUrl: import.meta.env.VITE_ASGARDEO_BASE_URL || '',
  scope: import.meta.env.VITE_ASGARDEO_SCOPES?.split(' ') || ['openid', 'profile'],
};

interface AuthProviderProps {
  children: React.ReactNode;
}

export const AuthProvider: React.FC<AuthProviderProps> = ({ children }) => {
  return (
    <AsgardeoAuthProvider config={authConfig}>
      {children}
    </AsgardeoAuthProvider>
  );
};
