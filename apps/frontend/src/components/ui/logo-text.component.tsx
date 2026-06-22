import React from 'react';

export const LogoTextComponent = () => {
  return (
    <svg
      width="220"
      height="48"
      viewBox="0 0 220 48"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
    >
      {/* Emerald accent mark */}
      <rect x="0" y="6" width="4" height="28" rx="2" fill="#10b981" />
      <rect x="8" y="12" width="4" height="16" rx="2" fill="#6366f1" />

      {/* "Cuanto Socials" wordmark */}
      <text
        x="20"
        y="24"
        fontFamily="'Plus Jakarta Sans', 'Helvetica Neue', sans-serif"
        fontWeight="700"
        fontSize="18"
        fill="currentColor"
        letterSpacing="-0.3"
      >
        Cuanto Socials
      </text>

      {/* "Management" sub-label */}
      <text
        x="20"
        y="40"
        fontFamily="'Plus Jakarta Sans', 'Helvetica Neue', sans-serif"
        fontWeight="400"
        fontSize="11"
        fill="#a1a1aa"
        letterSpacing="0.5"
      >
        MANAGEMENT · by Cuanto Labs
      </text>
    </svg>
  );
};
