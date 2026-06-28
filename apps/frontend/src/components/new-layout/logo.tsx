'use client';

// Cuanto Labs "C" mark — emerald tile, white C, indigo node.
// Brand system: emerald #10b981, indigo #6366f1, dark #131019.
export const Logo = () => {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="60"
      height="60"
      viewBox="0 0 60 60"
      fill="none"
      className="mt-[8px] min-w-[60px] min-h-[60px]"
    >
      <rect
        x="3"
        y="3"
        width="54"
        height="54"
        rx="14"
        fill="#10b981"
        stroke="#131019"
        strokeWidth="1.45"
      />
      <path
        d="M41.5 20.4 A15 15 0 1 0 41.5 39.6"
        fill="none"
        stroke="#ffffff"
        strokeWidth="7"
        strokeLinecap="round"
      />
      <circle cx="44" cy="30" r="3.4" fill="#6366f1" />
    </svg>
  );
};
