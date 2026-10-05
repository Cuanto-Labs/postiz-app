// Unit tests that run without the Nx preset — the root jest.config.ts imports
// @nx/jest, which is not installed, so `pnpm test` cannot even load its config.
// This reuses the mobile suite's ts-jest setup and adds the specs that guard
// billing and the locked AI models. CI runs it as a blocking step.
const mobile = require('./apps/backend/src/api/routes/mobile/jest.config.cjs');

module.exports = {
  ...mobile,
  rootDir: __dirname,
  testMatch: [
    ...mobile.testMatch,
    '<rootDir>/libraries/nestjs-libraries/src/chat/**/*.spec.ts',
    '<rootDir>/libraries/nestjs-libraries/src/database/prisma/subscriptions/**/*.spec.ts',
    '<rootDir>/libraries/nestjs-libraries/src/emails/**/*.spec.ts',
  ],
};
