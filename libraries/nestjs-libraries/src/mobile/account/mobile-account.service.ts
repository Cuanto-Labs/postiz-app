import { Injectable, Logger } from '@nestjs/common';
import { createHash } from 'crypto';
import { Role } from '@prisma/client';
import { TemporalService } from 'nestjs-temporal-core';
import { OrganizationRepository } from '@gitroom/nestjs-libraries/database/prisma/organizations/organization.repository';
import { IntegrationRepository } from '@gitroom/nestjs-libraries/database/prisma/integrations/integration.repository';
import { AccountDeletionRepository } from '@gitroom/nestjs-libraries/mobile/account/account-deletion.repository';
import { SubscriptionService } from '@gitroom/nestjs-libraries/database/prisma/subscriptions/subscription.service';
import { StripeService } from '@gitroom/nestjs-libraries/services/stripe.service';
import { EmailService } from '@gitroom/nestjs-libraries/services/email.service';

export type AccountOrgSummary = { id: string; name: string };

export type AccountDeletionPreview = {
  orgsToDelete: AccountOrgSummary[];
  orgsToLeave: AccountOrgSummary[];
};

@Injectable()
export class MobileAccountService {
  private readonly _logger = new Logger(MobileAccountService.name);

  constructor(
    private _organizationRepository: OrganizationRepository,
    private _integrationRepository: IntegrationRepository,
    private _accountDeletionRepository: AccountDeletionRepository,
    private _subscriptionService: SubscriptionService,
    private _stripeService: StripeService,
    private _emailService: EmailService,
    private _temporalService: TemporalService
  ) {}

  async preview(userId: string): Promise<AccountDeletionPreview> {
    const orgs = await this._organizationRepository.getOrgsByUserId(userId);
    const orgsToDelete: AccountOrgSummary[] = [];
    const orgsToLeave: AccountOrgSummary[] = [];

    for (const org of orgs) {
      const isSuperAdmin = org.users?.[0]?.role === Role.SUPERADMIN;
      const otherAdmins = isSuperAdmin
        ? await this._accountDeletionRepository.countOtherAdmins(
            org.id,
            userId
          )
        : 1;

      if (isSuperAdmin && otherAdmins === 0) {
        orgsToDelete.push({ id: org.id, name: org.name });
      } else {
        orgsToLeave.push({ id: org.id, name: org.name });
      }
    }

    return { orgsToDelete, orgsToLeave };
  }

  async deleteAccount(userId: string, email: string) {
    const { orgsToDelete, orgsToLeave } = await this.preview(userId);

    for (const org of orgsToDelete) {
      const posts = await this._accountDeletionRepository.listRunningPostIds([
        org.id,
      ]);
      for (const post of posts) {
        try {
          const workflows = this._temporalService.client
            .getRawClient()
            ?.workflow.list({
              query: `postId="${post.id}" AND ExecutionStatus="Running"`,
            });

          for await (const executionInfo of workflows) {
            try {
              const workflow =
                await this._temporalService.client.getWorkflowHandle(
                  executionInfo.workflowId
                );
              if (
                workflow &&
                (await workflow.describe()).status.name !== 'TERMINATED'
              ) {
                await workflow.terminate();
              }
            } catch (err) {}
          }
        } catch (err) {
          this._logger.error(
            `Failed to terminate post workflow ${post.id}`,
            err
          );
        }
      }

      const media =
        await this._accountDeletionRepository.listProcessingMediaIds([
          org.id,
        ]);
      for (const item of media) {
        try {
          const handle = await this._temporalService.client.getWorkflowHandle(
            `media_${item.id}`
          );
          await handle.terminate('account deleted');
        } catch (err) {
          this._logger.error(
            `Failed to terminate media workflow ${item.id}`,
            err
          );
        }
      }

      try {
        const subscription =
          await this._subscriptionService.getSubscriptionByOrganizationId(
            org.id
          );
        if (subscription) {
          await this._stripeService.setToCancel(org.id);
        }
      } catch (err) {
        this._logger.error(
          `Failed to cancel subscription for org ${org.id}`,
          err
        );
      }

      await this._integrationRepository.deleteIntegrationsForAccount(org.id);
      await this._accountDeletionRepository.softDeleteMedia(org.id);
      await this._organizationRepository.deleteOrganization(org.id);
    }

    for (const org of orgsToLeave) {
      await this._organizationRepository.deleteTeamMember(org.id, userId);
    }

    await this._accountDeletionRepository.revokeUserSessions(userId);

    const userIdHash = createHash('sha256').update(userId).digest('hex');
    await this._accountDeletionRepository.writeAudit({
      userIdHash,
      orgIdsDeleted: orgsToDelete.map((org) => org.id),
      orgIdsLeft: orgsToLeave.map((org) => org.id),
      source: 'mobile',
    });

    if (this._emailService.hasProvider()) {
      this._emailService
        .sendEmail(
          email,
          'Your account has been deleted',
          '<p>Your account and all associated data have been deleted.</p>',
          'bottom'
        )
        .catch((err: unknown) => {
          this._logger.error('Failed to send account deletion email', err);
        });
    }

    await this._accountDeletionRepository.anonymizeUser(
      userId,
      userIdHash.slice(0, 16)
    );

    return { deletedOrgs: orgsToDelete, leftOrgs: orgsToLeave };
  }
}
