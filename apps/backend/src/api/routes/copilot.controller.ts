import {
  Logger,
  Controller,
  Get,
  Post,
  Req,
  Res,
  Query,
  Param,
} from '@nestjs/common';
import {
  CopilotRuntime,
  OpenAIAdapter,
  copilotRuntimeNodeHttpEndpoint,
  copilotRuntimeNextJSAppRouterEndpoint,
} from '@copilotkit/runtime';
import OpenAI from 'openai';
import { GetOrgFromRequest } from '@gitroom/nestjs-libraries/user/org.from.request';
import { Organization } from '@prisma/client';
import { SubscriptionService } from '@gitroom/nestjs-libraries/database/prisma/subscriptions/subscription.service';
import { MastraAgent } from '@ag-ui/mastra';
import { MastraService } from '@gitroom/nestjs-libraries/chat/mastra.service';
import { Request, Response } from 'express';
import { RequestContext } from '@mastra/core/di';
import { CheckPolicies } from '@gitroom/backend/services/auth/permissions/permissions.ability';
import { AuthorizationActions, Sections } from '@gitroom/backend/services/auth/permissions/permission.exception.class';
import { AGENT_PROVIDERS, activeProviderConfig } from '@gitroom/nestjs-libraries/chat/load.tools.service';
import { ioRedis } from '@gitroom/nestjs-libraries/redis/redis.service';
import { REDIS_KEY_AGENT_MODEL } from './admin.controller';

// Shared OAI-compatible client for copilot adapters — follows provider pool.
const copilotOpenAI = new OpenAI({
  baseURL: activeProviderConfig.baseURL,
  apiKey: activeProviderConfig.apiKey,
});

export type ChannelsContext = {
  integrations: string;
  organization: string;
  ui: string;
};

@Controller('/copilot')
export class CopilotController {
  constructor(
    private _subscriptionService: SubscriptionService,
    private _mastraService: MastraService
  ) {}
  @Post('/chat')
  chatAgent(@Req() req: Request, @Res() res: Response) {
    if (!activeProviderConfig.apiKey) {
      Logger.warn(`No API key for provider ${process.env.AGENT_PROVIDER || 'opencode'}`);
      return;
    }

    const redisModel = await ioRedis.get(REDIS_KEY_AGENT_MODEL);
    const effectiveModel = redisModel || process.env.AGENT_MODEL || activeProviderConfig.defaultModel;

    const copilotRuntimeHandler = copilotRuntimeNodeHttpEndpoint({
      endpoint: '/copilot/chat',
      runtime: new CopilotRuntime(),
      serviceAdapter: new OpenAIAdapter({
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        openai: copilotOpenAI as any,
        model: effectiveModel,
      }),
    });

    return copilotRuntimeHandler(req, res);
  }

  @Post('/agent')
  @CheckPolicies([AuthorizationActions.Create, Sections.AI])
  async agent(
    @Req() req: Request,
    @Res() res: Response,
    @GetOrgFromRequest() organization: Organization
  ) {
    if (!activeProviderConfig.apiKey) {
      Logger.warn(`No API key for provider ${process.env.AGENT_PROVIDER || 'opencode'}`);
      return;
    }
    const mastra = await this._mastraService.mastra();
    const requestContext = new RequestContext<ChannelsContext>();
    requestContext.set(
      'integrations',
      req?.body?.variables?.properties?.integrations || []
    );

    requestContext.set('organization', JSON.stringify(organization));
    requestContext.set('ui', 'true');

    const agents = MastraAgent.getLocalAgents({
      resourceId: organization.id,
      mastra,
      requestContext: requestContext as any,
    });

    const runtime = new CopilotRuntime({
      agents,
    });

    const redisModel = await ioRedis.get(REDIS_KEY_AGENT_MODEL);
    const effectiveModel = redisModel || process.env.AGENT_MODEL || activeProviderConfig.defaultModel;

    const copilotRuntimeHandler = copilotRuntimeNextJSAppRouterEndpoint({
      endpoint: '/copilot/agent',
      runtime,
      // properties: req.body.variables.properties,
      serviceAdapter: new OpenAIAdapter({
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        openai: copilotOpenAI as any,
        model: effectiveModel,
      }),
    });

    return copilotRuntimeHandler.handleRequest(req, res);
  }

  @Get('/credits')
  calculateCredits(
    @GetOrgFromRequest() organization: Organization,
    @Query('type') type: 'ai_images' | 'ai_videos'
  ) {
    return this._subscriptionService.checkCredits(
      organization,
      type || 'ai_images'
    );
  }

  @Get('/:thread/list')
  @CheckPolicies([AuthorizationActions.Create, Sections.AI])
  async getMessagesList(
    @GetOrgFromRequest() organization: Organization,
    @Param('thread') threadId: string
  ): Promise<any> {
    const mastra = await this._mastraService.mastra();
    const memory = await mastra.getAgent('postiz').getMemory();
    try {
      return await memory.recall({
        resourceId: organization.id,
        threadId,
      });
    } catch (err) {
      return { messages: [] };
    }
  }

  @Get('/list')
  @CheckPolicies([AuthorizationActions.Create, Sections.AI])
  async getList(@GetOrgFromRequest() organization: Organization) {
    const mastra = await this._mastraService.mastra();
    const memory = await mastra.getAgent('postiz').getMemory();
    const list = await memory.listThreads({
      filter: { resourceId: organization.id },
      perPage: 100000,
      page: 0,
      orderBy: { field: 'createdAt', direction: 'DESC' },
    });

    return {
      threads: list.threads.map((p) => ({
        id: p.id,
        title: p.title,
      })),
    };
  }

  @Get('/providers')
  listProviders() {
    return {
      active: process.env.AGENT_PROVIDER || 'opencode',
      model: process.env.AGENT_MODEL || activeProviderConfig.defaultModel,
      providers: Object.entries(AGENT_PROVIDERS).map(([key, cfg]) => ({
        key,
        baseURL: cfg.baseURL,
        defaultModel: cfg.defaultModel,
      })),
    };
  }

  @Get('/models')
  async listModels() {
    try {
      const res = await fetch(`${activeProviderConfig.baseURL}/models`, {
        headers: { Authorization: `Bearer ${activeProviderConfig.apiKey}` },
      });
      const data = await res.json() as { data?: { id: string }[] };
      return {
        provider: process.env.AGENT_PROVIDER || 'opencode',
        models: (data.data ?? []).map((m) => m.id),
      };
    } catch {
      return { provider: process.env.AGENT_PROVIDER || 'opencode', models: [] };
    }
  }
}
