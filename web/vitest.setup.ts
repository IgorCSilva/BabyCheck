// Outside `src/` on purpose: tsconfig's `include` only covers `src/**/*`, so
// this file (and fake-indexeddb's untyped `/auto` subpath) never has to be
// type-checked by `vue-tsc` — vitest still loads it fine via esbuild.
import "fake-indexeddb/auto";
