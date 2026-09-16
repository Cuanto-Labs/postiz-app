module.exports = {
  rootDir: '../../../../../..',
  testEnvironment: 'node',
  testMatch: [
    '<rootDir>/apps/backend/src/api/routes/mobile/**/*.spec.ts',
    '<rootDir>/libraries/nestjs-libraries/src/mobile/**/*.spec.ts',
  ],
  transform: {
    '^.+\\.tsx?$': [
      'ts-jest',
      {
        tsconfig: '<rootDir>/apps/backend/tsconfig.json',
        isolatedModules: true,
      },
    ],
  },
  moduleNameMapper: {
    '^@gitroom/backend/(.*)$': '<rootDir>/apps/backend/src/$1',
    '^@gitroom/nestjs-libraries/(.*)$': '<rootDir>/libraries/nestjs-libraries/src/$1',
    '^@gitroom/helpers/(.*)$': '<rootDir>/libraries/helpers/src/$1',
  },
};
