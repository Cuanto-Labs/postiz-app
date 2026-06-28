'use client';

// Cuanto Labs "C" lettermark — solid emerald squircle, white C.
export const Logo = () => {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="60"
      height="60"
      viewBox="0 0 64 64"
      className="mt-[8px] min-w-[60px] min-h-[60px]"
    >
      <rect x="2" y="2" width="60" height="60" rx="15" fill="#059669" />
      <path
        d="M48.77 42.89 A20 20 0 1 1 48.77 21.11 L42.06 25.46 A12 12 0 1 0 42.06 38.54 Z"
        fill="#ffffff"
      />
    </svg>
  );
};
