import { ExecutionType, FlowRunStatus, isNil, LATEST_JOB_DATA_SCHEMA_VERSION, PauseType, ProgressUpdateType, WorkerJobType } from '@activepieces/shared'
import dayjs from 'dayjs'
import { FastifyBaseLogger } from 'fastify'
import { redisConnections } from '../../../database/redis-connections'
import { flowRunRepo } from '../../../flows/flow-run/flow-run-service'
import { projectService } from '../../../project/project-service'
import { jobQueue } from '../job-queue'
import { JobType } from '../queue-manager'


const REFILL_PAUSED_RUNS_KEY = 'refill_paused_runs'

export const refillPausedRuns = (log: FastifyBaseLogger) => ({
    async run(): Promise<void> {
        const redisConnection = await redisConnections.useExisting()
        const isMigrated = await redisConnection.get(REFILL_PAUSED_RUNS_KEY)
        if (!isNil(isMigrated)) {
            log.info('[refillPausedRuns] Already migrated, skipping')
            return
        }
        const pausedRuns = await flowRunRepo().find({
            where: {
                status: FlowRunStatus.PAUSED,
            },
        })
        for (const pausedRun of pausedRuns) {
            if (pausedRun.pauseMetadata?.type != PauseType.DELAY) {
                continue
            }
            await jobQueue(log).add({
                id: pausedRun.id,
                type: JobType.ONE_TIME,
                data: {
                    projectId: pausedRun.projectId,
                    platformId: await projectService.getPlatformId(pausedRun.projectId),
                    environment: pausedRun.environment,
                    schemaVersion: LATEST_JOB_DATA_SCHEMA_VERSION,
                    flowVersionId: pausedRun.flowVersionId,
                    runId: pausedRun.id,
                    httpRequestId: pausedRun.pauseMetadata?.requestIdToReply ?? undefined,
                    synchronousHandlerId: pausedRun.pauseMetadata.handlerId ?? null,
                    progressUpdateType: pausedRun.pauseMetadata.progressUpdateType ?? ProgressUpdateType.NONE,
                    jobType: WorkerJobType.EXECUTE_FLOW,
                    executionType: ExecutionType.RESUME,
                    payload: {},
                },
                delay: calculateDelayForPausedRun(pausedRun.pauseMetadata.resumeDateTime),
            })
        }
        log.info({
            count: pausedRuns.length,
        }, '[pausedRunsMigration] Migrated paused runs')
        await redisConnection.set(REFILL_PAUSED_RUNS_KEY, 'true')
    },
})

function calculateDelayForPausedRun(resumeDateTimeIsoString: string): number {
    const delayInMilliSeconds = dayjs(resumeDateTimeIsoString).diff(dayjs())
    return delayInMilliSeconds < 0 ? 0 : delayInMilliSeconds
}
