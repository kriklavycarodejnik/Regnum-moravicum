import { beforeAll, afterAll, afterEach } from 'vitest';

// Global test setup
beforeAll(() => {
  // Setup code that runs once before all tests
});

afterAll(() => {
  // Cleanup code that runs once after all tests
});

afterEach(() => {
  // Cleanup code that runs after each test
  // Clear all mocks
  vi.clearAllMocks();
});

// Mock console methods to reduce noise in tests
const originalConsoleError = console.error;
const originalConsoleWarn = console.warn;

beforeAll(() => {
  console.error = (...args: any[]) => {
    if (/React does not recognize the/.test(args[0])) {
      return; // Ignore React prop warnings in tests
    }
    originalConsoleError(...args);
  };
  
  console.warn = (...args: any[]) => {
    if (/React does not recognize the/.test(args[0])) {
      return; // Ignore React prop warnings in tests
    }
    originalConsoleWarn(...args);
  };
});

afterAll(() => {
  console.error = originalConsoleError;
  console.warn = originalConsoleWarn;
});
