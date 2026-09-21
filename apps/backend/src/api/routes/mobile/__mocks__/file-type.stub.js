// Test-only stub. The real `file-type` package (v22) is ESM-only and cannot
// be `require()`d under ts-jest's CJS transform. Nothing in the mobile auth
// test surface exercises file-type detection (it's pulled in transitively via
// UsersService -> integration.repository -> upload.factory -> cloudflare.storage),
// so a no-op stub keeps the module graph loadable without touching prod code.
module.exports = {
  fileTypeFromBuffer: async () => null,
};
