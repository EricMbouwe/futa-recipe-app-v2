import js from "@eslint/js";
import globals from "globals";
import reactHooks from "eslint-plugin-react-hooks";
import reactRefresh from "eslint-plugin-react-refresh";

export default [
  { ignores: [ "dist" ] },
  {
    files: [ "**/*.{js,jsx}" ],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: "module",
      globals: globals.browser,
      parserOptions: { ecmaFeatures: { jsx: true } },
    },
    plugins: { "react-hooks": reactHooks, "react-refresh": reactRefresh },
    rules: {
      ...js.configs.recommended.rules,
      ...reactHooks.configs.recommended.rules,
      // ESLint seul ne voit pas l'usage d'un composant en JSX.
      "no-unused-vars": [ "error", { varsIgnorePattern: "^[A-Z_]" } ],
      "react-refresh/only-export-components": [ "warn", { allowConstantExport: true } ],
    },
  },
  {
    files: [ "**/*.test.{js,jsx}", "src/test/**" ],
    languageOptions: { globals: { ...globals.node, ...globals.vitest } },
  },
  {
    files: [ "vite.config.js", "eslint.config.js" ],
    languageOptions: { globals: globals.node },
  },
];
