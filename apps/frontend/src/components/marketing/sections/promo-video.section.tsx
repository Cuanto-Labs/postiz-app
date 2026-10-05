'use client';

import { useEffect, useRef, useState } from 'react';

const CUTS = {
  wide: { file: 'ad-16x9', aspect: 'aspect-video', width: 'max-w-[960px]' },
  tall: { file: 'ad-9x16', aspect: 'aspect-[9/16]', width: 'max-w-[340px]' },
} as const;

/**
 * The 22s product promo: 16:9 on wide screens, 9:16 on phones (picked after
 * mount so a phone never downloads the wide cut). Muted autoplay loop with
 * controls; the source loads only once the player nears the viewport.
 * Rendered from ~/coding/adforge (promos/cuanto-socials/script.json).
 */
export const PromoVideoSection = () => {
  const [cut, setCut] = useState<keyof typeof CUTS>('wide');
  const [visible, setVisible] = useState(false);
  const tracked = useRef(false);
  const ref = useRef<HTMLVideoElement>(null);

  useEffect(() => {
    const mq = window.matchMedia('(max-width: 639px)');
    const sync = () => setCut(mq.matches ? 'tall' : 'wide');
    sync();
    mq.addEventListener('change', sync);
    return () => mq.removeEventListener('change', sync);
  }, []);

  useEffect(() => {
    const el = ref.current;
    if (!el || visible) return;
    const io = new IntersectionObserver(
      (entries) => {
        if (entries.some((e) => e.isIntersecting)) {
          setVisible(true);
          io.disconnect();
        }
      },
      { rootMargin: '200px' }
    );
    io.observe(el);
    return () => io.disconnect();
  }, [visible, cut]);

  const { file, aspect, width } = CUTS[cut];

  return (
    <section className="w-full px-[24px] pb-[72px]">
      <video
        key={cut}
        ref={ref}
        className={`w-full ${width} ${aspect} mx-auto block rounded-[16px] border border-white/10 bg-black object-cover`}
        src={visible ? `/videos/${file}.mp4` : undefined}
        poster={`/videos/${file}.jpg`}
        autoPlay
        muted
        loop
        playsInline
        controls
        preload="none"
        aria-label="Cuanto Socials: one post, published to every channel at once"
        // Autoplay starts every visit, so a play event says nothing. Unmuting
        // is the first thing only a watching visitor does.
        onVolumeChange={(e) => {
          if (tracked.current || e.currentTarget.muted) return;
          tracked.current = true;
          try {
            (
              window as unknown as {
                onyx?: { event: (n: string, p?: object) => void };
              }
            ).onyx?.event('promo_video_unmute', { video: 'cuanto-socials-ad', cut });
          } catch {
            // Analytics must never break the page it measures.
          }
        }}
      />
    </section>
  );
};
