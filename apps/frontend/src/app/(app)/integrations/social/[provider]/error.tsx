"use client";

// Route-level error boundary for the OAuth callback. Without it, any throw in
// the connect flow (bad state, expired code, provider hiccup) renders Next.js
// "Application error: a client-side exception has occurred" — a dead end for a
// user who just came back from Instagram/LinkedIn. Show what happened and send
// them back to the app instead.
import { useEffect } from "react";
import { useRouter } from "next/navigation";

export default function ConnectError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  const { push } = useRouter();

  useEffect(() => {
    console.error("channel connect failed", error);
  }, [error]);

  return (
    <div className="flex flex-1 items-center justify-center text-white relative overflow-hidden">
      <div className="absolute inset-0 opacity-30">
        <div className="absolute top-[20%] left-[10%] w-[300px] h-[300px] bg-[#10b981] rounded-full blur-[120px]" />
        <div className="absolute bottom-[20%] right-[10%] w-[250px] h-[250px] bg-[#10b981] rounded-full blur-[120px]" />
      </div>

      <div className="relative z-10 text-center">
        <div className="w-[80px] h-[80px] mx-auto mb-[24px] rounded-full bg-red-500/20 flex items-center justify-center">
          <svg
            className="w-[40px] h-[40px] text-red-500"
            fill="currentColor"
            viewBox="0 0 20 20"
          >
            <path
              fillRule="evenodd"
              d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z"
              clipRule="evenodd"
            />
          </svg>
        </div>
        <div className="text-[28px] font-semibold mb-[12px]">
          Could not connect the channel
        </div>
        <div className="text-[16px] text-gray-400 max-w-[420px] mb-[24px]">
          The connection link may have expired, or it was opened outside the
          app. Start again from Add Channel.
        </div>
        <div className="flex gap-[12px] justify-center">
          <button
            onClick={reset}
            className="h-[44px] px-[20px] rounded-[8px] bg-btnSimple text-btnText"
          >
            Try again
          </button>
          <button
            onClick={() => push("/launches")}
            className="h-[44px] px-[20px] rounded-[8px] bg-[#10b981] text-black font-medium"
          >
            Back to channels
          </button>
        </div>
      </div>
    </div>
  );
}
