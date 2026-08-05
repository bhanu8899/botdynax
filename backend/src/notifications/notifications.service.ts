import { Injectable, NotFoundException } from '@nestjs/common';
import { NotificationType } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class NotificationsService {
  constructor(private readonly prisma: PrismaService) {}

  findAll(userId: string) {
    return this.prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }

  /// Called via POST /notifications (client-detected events) or internally
  /// by the MQTT bridge for firmware that pushes events server-side.
  create(userId: string, type: NotificationType, message: string, robotId?: string) {
    return this.prisma.notification.create({ data: { userId, type, message, robotId } });
  }

  async markRead(userId: string, notificationId: string) {
    const notification = await this.prisma.notification.findUnique({ where: { id: notificationId } });
    if (!notification || notification.userId !== userId) {
      throw new NotFoundException('Notification not found');
    }
    return this.prisma.notification.update({ where: { id: notificationId }, data: { read: true } });
  }
}
