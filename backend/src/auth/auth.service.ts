import { createHash, randomUUID } from 'crypto';

import { ConflictException, Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService, JwtSignOptions } from '@nestjs/jwt';
import { AuthProvider } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { OAuth2Client } from 'google-auth-library';
import * as jwt from 'jsonwebtoken';
import jwksClient from 'jwks-rsa';

import { PrismaService } from '../prisma/prisma.service';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { AuthTokens, AuthenticatedUser, JwtPayload } from './jwt-payload.interface';

const APPLE_JWKS_URI = 'https://appleid.apple.com/auth/keys';
const APPLE_ISSUER = 'https://appleid.apple.com';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);
  private readonly googleClient: OAuth2Client;
  private readonly appleJwks = jwksClient({ jwksUri: APPLE_JWKS_URI });

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {
    this.googleClient = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);
  }

  async register(dto: RegisterDto): Promise<AuthTokens> {
    const existing = await this.prisma.user.findUnique({ where: { email: dto.email } });
    if (existing) {
      throw new ConflictException('An account with this email already exists');
    }

    const passwordHash = await bcrypt.hash(dto.password, 12);
    const user = await this.prisma.user.create({
      data: {
        email: dto.email,
        passwordHash,
        name: dto.name,
        authProvider: AuthProvider.EMAIL,
      },
    });

    return this.issueTokens(user.id, user.email);
  }

  async login(dto: LoginDto): Promise<AuthTokens> {
    const user = await this.prisma.user.findUnique({ where: { email: dto.email } });
    if (!user?.passwordHash || !(await bcrypt.compare(dto.password, user.passwordHash))) {
      throw new UnauthorizedException('Invalid email or password');
    }
    return this.issueTokens(user.id, user.email);
  }

  async loginAsGuest(): Promise<AuthTokens> {
    const user = await this.prisma.user.create({
      data: {
        name: `Guest-${randomUUID().slice(0, 8)}`,
        authProvider: AuthProvider.GUEST,
      },
    });
    return this.issueTokens(user.id, user.email);
  }

  /// Verifies a Google ID token via Google's official verification library,
  /// then upserts a local user record keyed on the token's stable subject
  /// (`sub`) claim. Requires `GOOGLE_CLIENT_ID` to be set to your OAuth
  /// client ID — that is the only thing that needs to change to go live.
  async loginWithGoogle(idToken: string): Promise<AuthTokens> {
    const audience = this.config.get<string>('GOOGLE_CLIENT_ID') ?? process.env.GOOGLE_CLIENT_ID;
    const ticket = await this.googleClient.verifyIdToken({ idToken, audience });
    const payload = ticket.getPayload();
    if (!payload?.sub) {
      throw new UnauthorizedException('Invalid Google token');
    }

    const user = await this.prisma.user.upsert({
      where: { email: payload.email ?? `google:${payload.sub}@botdynax.local` },
      update: {},
      create: {
        email: payload.email ?? `google:${payload.sub}@botdynax.local`,
        name: payload.name ?? 'BotDyNax User',
        authProvider: AuthProvider.GOOGLE,
      },
    });
    return this.issueTokens(user.id, user.email);
  }

  /// Verifies an Apple identity token against Apple's published JWKS.
  /// Requires `APPLE_CLIENT_ID` (your Services ID) to validate the
  /// audience — again, the only value that needs to change per app.
  async loginWithApple(idToken: string): Promise<AuthTokens> {
    const decoded = jwt.decode(idToken, { complete: true });
    const kid = decoded?.header.kid;
    if (!kid) {
      throw new UnauthorizedException('Invalid Apple token');
    }

    const signingKey = await this.appleJwks.getSigningKey(kid);
    const audience = this.config.get<string>('APPLE_CLIENT_ID') ?? process.env.APPLE_CLIENT_ID;

    let payload: jwt.JwtPayload;
    try {
      payload = jwt.verify(idToken, signingKey.getPublicKey(), {
        issuer: APPLE_ISSUER,
        audience,
      }) as jwt.JwtPayload;
    } catch (error) {
      this.logger.warn(`Apple token verification failed: ${(error as Error).message}`);
      throw new UnauthorizedException('Invalid Apple token');
    }

    const appleSub = payload.sub;
    if (!appleSub) {
      throw new UnauthorizedException('Invalid Apple token');
    }

    const email = typeof payload.email === 'string' ? payload.email : `apple:${appleSub}@botdynax.local`;
    const user = await this.prisma.user.upsert({
      where: { email },
      update: {},
      create: { email, name: 'BotDyNax User', authProvider: AuthProvider.APPLE },
    });
    return this.issueTokens(user.id, user.email);
  }

  async refresh(refreshToken: string): Promise<AuthTokens> {
    let payload: JwtPayload;
    try {
      payload = await this.jwt.verifyAsync<JwtPayload>(refreshToken, {
        secret: this.config.get<string>('jwt.refreshSecret'),
      });
    } catch {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    const tokenHash = this.hashToken(refreshToken);
    const stored = await this.prisma.refreshToken.findUnique({ where: { tokenHash } });
    if (!stored || stored.revoked || stored.expiresAt < new Date()) {
      throw new UnauthorizedException('Refresh token has been revoked');
    }

    await this.prisma.refreshToken.update({ where: { id: stored.id }, data: { revoked: true } });
    return this.issueTokens(payload.sub, payload.email);
  }

  async forgotPassword(dto: ForgotPasswordDto): Promise<{ message: string }> {
    const user = await this.prisma.user.findUnique({ where: { email: dto.email } });
    // Always return the same message whether or not the account exists, to
    // avoid leaking which emails are registered.
    if (user) {
      const resetToken = randomUUID();
      // *** WIRE UP A REAL EMAIL PROVIDER HERE ***
      // (SendGrid/SES/Postmark). The reset token itself is real and should
      // be persisted with an expiry and consumed by a `/auth/reset-password`
      // endpoint; only the outbound email send is a stand-in.
      this.logger.log(`Password reset requested for ${dto.email} — token: ${resetToken}`);
    }
    return { message: 'If that email is registered, a reset link has been sent.' };
  }

  async validateUserById(userId: string): Promise<AuthenticatedUser | null> {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) return null;
    return { id: user.id, email: user.email, name: user.name };
  }

  private async issueTokens(userId: string, email: string | null): Promise<AuthTokens> {
    const payload: JwtPayload = { sub: userId, email };

    const accessToken = await this.jwt.signAsync(payload, {
      secret: this.config.get<string>('jwt.accessSecret'),
      // jsonwebtoken's typings require a branded `StringValue` template
      // literal for `expiresIn`; our config value is a plain (but
      // runtime-valid, e.g. "15m") string, so a cast is required here.
      expiresIn: this.config.get<string>('jwt.accessExpiresIn') as JwtSignOptions['expiresIn'],
    });

    const refreshExpiresInDays = this.config.get<number>('jwt.refreshExpiresInDays') ?? 30;
    const refreshToken = await this.jwt.signAsync(payload, {
      secret: this.config.get<string>('jwt.refreshSecret'),
      expiresIn: `${refreshExpiresInDays}d` as JwtSignOptions['expiresIn'],
    });

    await this.prisma.refreshToken.create({
      data: {
        tokenHash: this.hashToken(refreshToken),
        userId,
        expiresAt: new Date(Date.now() + refreshExpiresInDays * 24 * 60 * 60 * 1000),
      },
    });

    return { accessToken, refreshToken };
  }

  private hashToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }
}
