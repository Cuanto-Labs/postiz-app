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
    // file-type v22+ is ESM-only and cannot be require()'d under ts-jest's
    // CJS transform; it's pulled in transitively via UsersService's storage
    // dependencies but never exercised by mobile auth tests.
    '^file-type$':
      '<rootDir>/apps/backend/src/api/routes/mobile/__mocks__/file-type.stub.js',
  },
};
