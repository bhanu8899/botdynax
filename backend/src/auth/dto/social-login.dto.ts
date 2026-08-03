import { IsString } from 'class-validator';

/// Google/Apple sign-in: the app hands us the provider's ID token, we
/// verify it and upsert a local user.
///
/// *** WIRE UP REAL TOKEN VERIFICATION ***
/// See AuthService.loginWithGoogle / loginWithApple for the exact spot to
/// plug in `google-auth-library` (verifyIdToken) and Apple's JWKS-based
/// verification respectively.
export class SocialLoginDto {
  @IsString()
  idToken!: string;
}
