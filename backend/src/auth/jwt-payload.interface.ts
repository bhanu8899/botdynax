export interface JwtPayload {
  sub: string;
  email: string | null;
}

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
}

export interface AuthenticatedUser {
  id: string;
  email: string | null;
  name: string;
}
