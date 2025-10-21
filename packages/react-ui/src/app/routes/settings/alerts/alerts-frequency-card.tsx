import { BellIcon, EyeNoneIcon, EyeOpenIcon } from '@radix-ui/react-icons';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { t } from 'i18next';
import React from 'react';

import { DashboardPageHeader } from '@/components/custom/dashboard-page-header';
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card';
import { useToast } from '@/components/ui/use-toast';
import { useAuthorization } from '@/hooks/authorization-hooks';
import { projectHooks } from '@/hooks/project-hooks';
import { authenticationSession } from '@/lib/authentication-session';
import { projectApi } from '@/lib/project-api';
import {
  NotificationStatus,
  Permission,
  ProjectWithLimits,
} from '@activepieces/shared';

import { AlertOption } from './alert-option';

const AlertFrequencyCard = React.memo(() => {
  const queryClient = useQueryClient();
  const { project, updateCurrentProject } = projectHooks.useCurrentProject();
  const { toast } = useToast();
  const { checkAccess } = useAuthorization();
  const writeAlertPermission =
    checkAccess(Permission.WRITE_ALERT) &&
    checkAccess(Permission.WRITE_PROJECT);

  return (
    <Card className="w-full">
      <DashboardPageHeader
        title={t('Alerts')}
        description={t('Manage alerts settings')}
      />

      <CardHeader className="pb-3">
        <CardTitle className="text-xl">{t('Alerts')}</CardTitle>
        <CardDescription>
          {t('Choose what you want to be notified about.')}
        </CardDescription>
        {writeAlertPermission === false && (
          <p>
            <span className="text-destructive">*</span>{' '}
            {t(
              'Project and alert permissions are required to change this setting.',
            )}
          </p>
        )}
      </CardHeader>
      <CardContent className="grid gap-1">
      </CardContent>
    </Card>
  );
});

AlertFrequencyCard.displayName = 'AlertFrequencyCard';
export { AlertFrequencyCard };
