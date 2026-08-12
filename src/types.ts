export interface ConfigForm {
  apiKey: string;
  baseUrl: string;
  modelName: string;
  npmMirror: string;
  proxy: string;
}

export interface EnvVarsStatus {
  auth_token_set: boolean;
  base_url_set: boolean;
  model_set: boolean;
  all_set: boolean;
  source: string;
}

export interface EnvironmentStatus {
  node_installed: boolean;
  node_version: string;
  node_path: string;
  npm_installed: boolean;
  npm_version: string;
  claude_installed: boolean;
  claude_version: string;
  env_configured: boolean;
  env_vars_status: EnvVarsStatus;
}

export interface LogItem {
  status: "info" | "success" | "error" | "loading";
  message: string;
}
