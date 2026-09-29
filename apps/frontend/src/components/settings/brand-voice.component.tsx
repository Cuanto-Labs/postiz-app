'use client';

import React, { useCallback, useEffect, useState } from 'react';
import { useFetch } from '@gitroom/helpers/utils/custom.fetch';
import useSWR from 'swr';
import { Button } from '@gitroom/react/form/button';
import { useToaster } from '@gitroom/react/toaster/toaster';
import { useT } from '@gitroom/react/translation/get.transation.service.client';

const BRAND_VOICE_MAX_LENGTH = 1000;

interface BrandVoiceResponse {
  brandVoice: string | null;
}

export const useBrandVoice = () => {
  const fetch = useFetch();

  const load = useCallback(async () => {
    return (await fetch('/settings/brand-voice')).json();
  }, []);

  return useSWR<BrandVoiceResponse>('brand-voice', load, {
    revalidateOnFocus: false,
    revalidateOnReconnect: false,
    revalidateIfStale: false,
    revalidateOnMount: true,
    refreshWhenHidden: false,
    refreshWhenOffline: false,
  });
};

const BrandVoiceComponent = () => {
  const t = useT();
  const fetch = useFetch();
  const toaster = useToaster();
  const { data, isLoading, mutate } = useBrandVoice();

  const [localValue, setLocalValue] = useState('');
  const [saving, setSaving] = useState(false);

  // Sync local state with fetched data
  useEffect(() => {
    setLocalValue(data?.brandVoice || '');
  }, [data]);

  const save = useCallback(async () => {
    setSaving(true);
    try {
      const response = await fetch('/settings/brand-voice', {
        method: 'POST',
        body: JSON.stringify({ brandVoice: localValue }),
      });
      if (!response.ok) {
        toaster.show(
          t('brand_voice_not_saved', 'Could not save the brand voice'),
          'warning'
        );
        return;
      }

      mutate(await response.json());
      toaster.show(t('settings_updated', 'Settings updated'), 'success');
    } finally {
      setSaving(false);
    }
  }, [fetch, localValue, mutate, toaster, t]);

  if (isLoading) {
    return (
      <div className="my-[16px] mt-[16px] bg-sixth border-fifth border rounded-[4px] p-[24px]">
        <div className="animate-pulse">{t('loading', 'Loading...')}</div>
      </div>
    );
  }

  return (
    <div className="my-[16px] mt-[16px] bg-sixth border-fifth border rounded-[4px] p-[24px] flex flex-col gap-[24px]">
      <div className="mt-[4px]">{t('brand_voice', 'Brand Voice')}</div>
      <div className="flex flex-col gap-[12px]">
        <div className="text-[12px] text-customColor18">
          {t(
            'brand_voice_description',
            'Describe how your brand sounds: tone, words to use or avoid, audience. The AI follows it whenever it writes posts for you.'
          )}
        </div>
        <textarea
          value={localValue}
          onChange={(e) => setLocalValue(e.target.value)}
          maxLength={BRAND_VOICE_MAX_LENGTH}
          placeholder={t(
            'brand_voice_placeholder',
            'Friendly and direct. Short sentences. No jargon, no emojis. We talk to small business owners.'
          )}
          className="bg-input min-h-[120px] p-[16px] outline-none border-fifth border rounded-[4px] text-inputText placeholder-inputText"
        />
        <div className="flex items-center justify-between gap-[24px]">
          <div className="text-[12px] text-customColor18">
            {localValue.length}/{BRAND_VOICE_MAX_LENGTH}
          </div>
          <Button type="button" loading={saving} onClick={save}>
            {t('save', 'Save')}
          </Button>
        </div>
      </div>
    </div>
  );
};

export default BrandVoiceComponent;
