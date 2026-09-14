import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");

  return {
    plugins: [ react() ],
    server: {
      port: 5173,
      // /v1 est relayé vers l'API : front et API partagent l'origine, comme en production.
      proxy: {
        "/v1": { target: env.API_PROXY_TARGET || "http://localhost:3000", changeOrigin: true },
      },
    },
    test: {
      environment: "jsdom",
      globals: true,
      setupFiles: "./src/test/setup.js",
      css: false,
    },
  };
});
