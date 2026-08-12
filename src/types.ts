export interface ConfigForm {
  apiKey: string;
  baseUrl: string;
  modelName: string;
}

export interface EnvironmentStatus {
  node_installed: boolean;
  node_version: string;
  npm_installed: boolean;
  npm_version: string;
  claude_installed: boolean;
  claude_version: string;
  env_configured: boolean;
}

export interface LogItem {
  status: "info" | "success" | "error" | "loading";
  message: string;
}
