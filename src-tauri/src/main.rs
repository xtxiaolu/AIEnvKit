// src-tauri/src/main.rs
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::process::Command;
use tauri::Emitter;
use tauri::Manager;
use tauri_plugin_shell::ShellExt;

#[derive(Debug, Clone, Deserialize)]
struct ConfigPayload {
    api_key: String,
    base_url: String,
    model_name: String,
    #[serde(default)]
    npm_mirror: String,
    #[serde(default)]
    proxy: String,
}

#[derive(Debug, Clone, Serialize)]
struct EnvironmentStatus {
    node_installed: bool,
    node_version: String,
    node_path: String,
    npm_installed: bool,
    npm_version: String,
    claude_installed: bool,
    claude_version: String,
    env_configured: bool,
    env_vars_status: EnvVarsStatus,
}

#[derive(Debug, Clone, Serialize)]
struct EnvVarsStatus {
    auth_token_set: bool,
    base_url_set: bool,
    model_set: bool,
    all_set: bool,
    source: String,
}

// 获取 resources 目录下的跨平台脚本路径
fn script_path(app: &tauri::AppHandle, name: &str) -> Result<PathBuf, String> {
    let script = format!(
        "scripts/{}/{}",
        platform_folder(),
        script_file_name(name)
    );

    app.path()
        .resolve(&script, tauri::path::BaseDirectory::Resource)
        .map_err(|e| format!("无法解析资源路径: {}", e))
}

fn platform_folder() -> &'static str {
    if cfg!(target_os = "windows") {
        "windows"
    } else {
        "macos"
    }
}

fn script_file_name(name: &str) -> String {
    if cfg!(target_os = "windows") {
        format!("{}.ps1", name)
    } else {
        format!("{}.sh", name)
    }
}

async fn run_script(
    app: &tauri::AppHandle,
    window: Option<&tauri::Window>,
    name: &str,
    args: &[&str],
) -> Result<String, String> {
    let path = script_path(app, name)?;

    if !path.exists() {
        return Err(format!("脚本不存在: {}", path.display()));
    }

    let path_str = path.to_string_lossy().to_string();

    let (program, mut cmd_args): (&str, Vec<&str>) = if cfg!(target_os = "windows") {
        (
            "powershell",
            vec!["-ExecutionPolicy", "Bypass", "-File", &path_str],
        )
    } else {
        ("bash", vec![&path_str])
    };

    if !args.is_empty() {
        cmd_args.extend(args);
    }

    let shell = app.shell();
    let mut command = shell.command(program);
    command = command.args(&cmd_args);

    let output = command
        .output()
        .await
        .map_err(|e| format!("执行脚本失败: {}", e))?;

    let stdout = String::from_utf8_lossy(&output.stdout).to_string();
    let stderr = String::from_utf8_lossy(&output.stderr).to_string();

    if let Some(win) = window {
        let _ = win.emit(
            "script-output",
            format!("{}\n{}", stdout, stderr).trim().to_string(),
        );
    }

    if !output.status.success() {
        return Err(format!(
            "脚本 {} 执行失败 (exit {}): {} {}",
            name,
            output
                .status
                .code()
                .map(|c| c.to_string())
                .unwrap_or_else(|| "signal".to_string()),
            stdout,
            stderr
        ));
    }

    Ok(format!("{}\n{}", stdout, stderr).trim().to_string())
}

#[tauri::command]
async fn test_connection(
    api_key: String,
    base_url: String,
    model_name: String,
) -> Result<String, String> {
    if api_key.trim().is_empty() || base_url.trim().is_empty() {
        return Err("API Key 和 API 地址不能为空".to_string());
    }

    let client = reqwest::Client::new();
    let url = format!("{}/models", base_url.trim_end_matches('/'));

    let res = client
        .get(&url)
        .header("Authorization", format!("Bearer {}", api_key))
        .timeout(std::time::Duration::from_secs(8))
        .send()
        .await
        .map_err(|e| format!("请求失败: {}", e))?;

    let status = res.status();
    let body = res.text().await.unwrap_or_else(|_| "<无法读取响应>".to_string());

    if status.is_success() {
        Ok(format!("✅ 连接成功 (HTTP {})，模型 {} 可用", status, model_name))
    } else {
        Err(format!("❌ 连接异常 (HTTP {}): {}", status, body))
    }
}

#[tauri::command]
async fn execute_configure(
    app: tauri::AppHandle,
    window: tauri::Window,
    payload: ConfigPayload,
) -> Result<String, String> {
    if payload.api_key.trim().is_empty() {
        return Err("API Key 不能为空".to_string());
    }

    let api_key = payload.api_key.trim();
    let base_url = payload.base_url.trim();
    let model_name = payload.model_name.trim();

    let npm_mirror = payload.npm_mirror.trim();
    let proxy = payload.proxy.trim();

    let args: Vec<&str> = vec![api_key, base_url, model_name, npm_mirror, proxy];

    let _ = window.emit("configure-step", "环境检测");
    let _ = window.emit("configure-step", "检查 Claude Code CLI");
    let _ = window.emit("configure-step", "备份原配置");
    let _ = window.emit("configure-step", "写入 Claude Code 配置");
    let _ = window.emit("configure-step", "设置环境变量");
    let _ = window.emit("configure-step", "最终验证");

    let result = run_script(&app, Some(&window), "set-env", &args).await?;

    Ok(format!("✅ 配置完成\n{}", result))
}

#[tauri::command]
async fn restore_backup(app: tauri::AppHandle) -> Result<String, String> {
    run_script(&app, None, "restore-backup", &[]).await
}

#[tauri::command]
fn get_claude_path() -> Result<String, String> {
    if cfg!(target_os = "windows") {
        let home = std::env::var("USERPROFILE")
            .map_err(|_| "无法获取 USERPROFILE".to_string())?;
        Ok(format!("{}\\.claude\\settings.json", home))
    } else {
        let home = std::env::var("HOME").map_err(|_| "无法获取 HOME".to_string())?;
        Ok(format!("{}/.claude/settings.json", home))
    }
}

#[tauri::command]
async fn check_environment() -> Result<EnvironmentStatus, String> {
    // 通过登录 shell 检测，确保能读取 .zshrc / .bash_profile 中的 PATH
    let (node_installed, node_version, node_path) = detect_program("node --version");
    let (npm_installed, npm_version, _npm_path) = detect_program("npm --version");
    let (claude_installed, claude_version, _claude_path) = detect_program("claude --version");

    let env_vars_status = check_env_vars_status();

    Ok(EnvironmentStatus {
        node_installed,
        node_version,
        node_path,
        npm_installed,
        npm_version,
        claude_installed,
        claude_version,
        env_configured: env_vars_status.all_set,
        env_vars_status,
    })
}

fn detect_program(command: &str) -> (bool, String, String) {
    let shell = get_user_shell();
    let shell_arg = "-lc";

    let output = Command::new(&shell)
        .args([shell_arg, command])
        .output();

    match output {
        Ok(output) if output.status.success() => {
            let ver = String::from_utf8_lossy(&output.stdout).trim().to_string();
            if ver.is_empty() {
                return (false, "未安装".to_string(), String::new());
            }
            // 尝试获取路径
            let path = if command.starts_with("node") {
                get_program_path("node")
            } else if command.starts_with("npm") {
                get_program_path("npm")
            } else if command.starts_with("claude") {
                get_program_path("claude")
            } else {
                String::new()
            };
            (true, ver, path)
        }
        _ => (false, "未安装".to_string(), String::new()),
    }
}

fn get_program_path(program: &str) -> String {
    let shell = get_user_shell();
    let output = Command::new(&shell)
        .args(["-lc", &format!("command -v {}", program)])
        .output();

    match output {
        Ok(output) if output.status.success() => {
            String::from_utf8_lossy(&output.stdout).trim().to_string()
        }
        _ => String::new(),
    }
}

fn get_user_shell() -> String {
    if let Ok(shell) = std::env::var("SHELL") {
        shell
    } else if cfg!(target_os = "macos") {
        "/bin/zsh".to_string()
    } else {
        "/bin/bash".to_string()
    }
}

fn check_env_vars_status() -> EnvVarsStatus {
    let mut status = EnvVarsStatus {
        auth_token_set: false,
        base_url_set: false,
        model_set: false,
        all_set: false,
        source: "未配置".to_string(),
    };

    // 读取当前进程环境变量
    if let Ok(token) = std::env::var("ANTHROPIC_AUTH_TOKEN") {
        if !token.is_empty() {
            status.auth_token_set = true;
            status.source = "进程环境变量".to_string();
        }
    }
    if let Ok(url) = std::env::var("ANTHROPIC_BASE_URL") {
        if !url.is_empty() {
            status.base_url_set = true;
        }
    }
    if let Ok(model) = std::env::var("ANTHROPIC_MODEL") {
        if !model.is_empty() {
            status.model_set = true;
        }
    }

    // 如果进程环境变量不完整，检查持久化配置
    if !status.all_set {
        check_persistent_env(&mut status);
    }

    status.all_set = status.auth_token_set && status.base_url_set && status.model_set;
    status
}

#[cfg(target_os = "windows")]
fn check_persistent_env(status: &mut EnvVarsStatus) {
    use std::process::Command;

    // Windows：读取用户环境变量（通过注册表）
    let keys = [
        ("ANTHROPIC_AUTH_TOKEN", &mut status.auth_token_set),
        ("ANTHROPIC_BASE_URL", &mut status.base_url_set),
        ("ANTHROPIC_MODEL", &mut status.model_set),
    ];

    for (key, flag) in keys.iter_mut() {
        if let Ok(output) = Command::new("powershell")
            .args([
                "-Command",
                &format!(
                    "[Environment]::GetEnvironmentVariable('{}', 'User')",
                    key
                ),
            ])
            .output()
        {
            let val = String::from_utf8_lossy(&output.stdout).trim().to_string();
            if !val.is_empty() {
                **flag = true;
            }
        }
    }

    if status.auth_token_set && status.base_url_set && status.model_set {
        status.source = "Windows 用户环境变量".to_string();
    }
}

#[cfg(not(target_os = "windows"))]
fn check_persistent_env(status: &mut EnvVarsStatus) {
    let shell_profile = get_shell_profile();
    let content = match std::fs::read_to_string(&shell_profile) {
        Ok(c) => c,
        Err(_) => return,
    };

    if !content.contains("# AIEnvKit auto-generated config") {
        return;
    }

    if content.contains("export ANTHROPIC_AUTH_TOKEN=") || content.contains("ANTHROPIC_AUTH_TOKEN=") {
        status.auth_token_set = true;
    }
    if content.contains("export ANTHROPIC_BASE_URL=") || content.contains("ANTHROPIC_BASE_URL=") {
        status.base_url_set = true;
    }
    if content.contains("export ANTHROPIC_MODEL=") || content.contains("ANTHROPIC_MODEL=") {
        status.model_set = true;
    }

    if status.auth_token_set && status.base_url_set && status.model_set {
        status.source = format!("Shell profile: {}", shell_profile.display());
    }
}

fn get_shell_profile() -> PathBuf {
    if let Ok(shell) = std::env::var("SHELL") {
        let shell_name = std::path::Path::new(&shell)
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or("zsh");
        match shell_name {
            "zsh" => PathBuf::from(format!("{}/.zshrc", std::env::var("HOME").unwrap_or_default())),
            "bash" => {
                let bash_profile = PathBuf::from(format!(
                    "{}/.bash_profile",
                    std::env::var("HOME").unwrap_or_default()
                ));
                if bash_profile.exists() {
                    bash_profile
                } else {
                    PathBuf::from(format!(
                        "{}/.bashrc",
                        std::env::var("HOME").unwrap_or_default()
                    ))
                }
            }
            _ => PathBuf::from(format!(
                "{}/.profile",
                std::env::var("HOME").unwrap_or_default()
            )),
        }
    } else {
        PathBuf::from(format!(
            "{}/.zshrc",
            std::env::var("HOME").unwrap_or_default()
        ))
    }
}

#[tauri::command]
async fn install_node(
    app: tauri::AppHandle,
    window: tauri::Window,
    mirror: String,
    proxy: String,
) -> Result<String, String> {
    let mirror = mirror.trim();
    let proxy = proxy.trim();
    let args: Vec<&str> = vec![mirror, proxy];

    run_script(&app, Some(&window), "install-node", &args).await
}

#[tauri::command]
async fn open_node_download_page(app: tauri::AppHandle) -> Result<(), String> {
    let opener = tauri_plugin_opener::OpenerExt::opener(&app);
    opener
        .open_url("https://nodejs.org/", None::<&str>)
        .map_err(|e| format!("打开下载页面失败: {}", e))?;
    Ok(())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_opener::init())
        .invoke_handler(tauri::generate_handler![
            test_connection,
            execute_configure,
            restore_backup,
            get_claude_path,
            check_environment,
            install_node,
            open_node_download_page,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
