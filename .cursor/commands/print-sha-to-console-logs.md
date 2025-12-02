# Print SHA to Console Logs

This guide documents how to inject the git commit SHA into the application and log it to the console for debugging and deployment tracking purposes.

## Overview

The implementation consists of three parts:
1. **Vite configuration** - Injects the commit SHA as an environment variable at build time
2. **Utility functions** - Provides functions to retrieve and log the commit SHA
3. **App component integration** - Initializes commit logging on app startup

## Implementation

### 1. Vite Configuration (`vite.config.ts`)

The Vite config extracts the git commit SHA and makes it available as an environment variable:

```typescript
import { execSync } from "child_process";

// Get git commit SHA, fallback to 'unknown' if git is not available
const getCommitSHA = () => {
  try {
    return execSync('git rev-parse HEAD').toString().trim();
  } catch {
    return 'unknown';
  }
};

export default defineConfig(({ mode }) => ({
  define: {
    'import.meta.env.VITE_COMMIT_SHA': JSON.stringify(
      process.env.VITE_COMMIT_SHA || getCommitSHA()
    ),
  },
  // ... rest of config
}));
```

**Key points:**
- Uses `git rev-parse HEAD` to get the current commit SHA
- Falls back to 'unknown' if git is unavailable or command fails
- Respects `process.env.VITE_COMMIT_SHA` if set (useful for CI/CD)
- Injects the value as `import.meta.env.VITE_COMMIT_SHA` in the app

### 2. Utility File (`src/utils/git.ts`)

Provides functions to retrieve and log the commit SHA:

```typescript
export const getCommitSHA = (): string => {
  return import.meta.env.VITE_COMMIT_SHA || 'unknown';
};

export const startCommitLogging = (): void => {
  const logCommitInfo = () => {
    const commitSHA = getCommitSHA();
    console.log(`the web app is running SHA id ${commitSHA}`);
  };

  logCommitInfo();

  setInterval(logCommitInfo, 60000);
};
```

**Key points:**
- `getCommitSHA()` retrieves the SHA from the environment variable
- `startCommitLogging()` logs the SHA immediately and then every 60 seconds
- Useful for debugging which version is running in production

### 3. App Component Integration (`src/App.tsx`)

Initialize commit logging when the app starts:

```typescript
import { useEffect } from "react";
import { startCommitLogging } from "@/utils/git";

const App = () => {
  useEffect(() => {
    startCommitLogging();
  }, []);

  return (
    // ... app JSX
  );
};
```

**Key points:**
- Calls `startCommitLogging()` once on component mount
- Uses `useEffect` with empty dependency array to run only on mount
- Logs will appear in the browser console

## Usage

Once implemented, the console will show:
```
the web app is running SHA id abc123def456...
```

This message appears:
- Immediately when the app loads
- Every 60 seconds thereafter

## Benefits

1. **Deployment tracking** - Quickly identify which version is running
2. **Debugging** - Match console logs to specific code versions
3. **Production verification** - Confirm the correct build is deployed
4. **CI/CD integration** - Can override with `VITE_COMMIT_SHA` environment variable

## Environment Variable Override

For CI/CD pipelines, you can override the git command by setting:
```bash
VITE_COMMIT_SHA=your-sha-here npm run build
```

This is useful when:
- Building in environments without git access
- Using specific commit SHAs from CI/CD systems
- Testing with custom SHA values

