// Backend-safe mirror of the frontend brand constant
// (`@gitroom/react/translation/brand`). Nestjs code (backend/orchestrator)
// cannot import react-shared-libraries, so this reads the same env var with
// the same default rather than hardcoding the product name in N places.
export const BRAND_NAME = process.env.NEXT_PUBLIC_BRAND_NAME || 'Cuanto Socials';
