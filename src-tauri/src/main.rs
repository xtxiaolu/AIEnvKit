// src-tauri/src/main.rs
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use std::process::Command;
use tauri::Emitter;
use tauri_plugin_shell::ShellExt;

#[derive(Debug, Clone, Deserialize)]
struct ConfigPayload {
    api_key: String,
    base_url: String,
    model_name: String,
}

#[derive(Debug, Clone, Serialize)]
struct EnvironmentStatus {
    node_installed: bool,
    node_version: String,
    npm_installed: bool,
    npm_version: String,
    claude_installed: bool,
    claude_version: String,
    env_configured: bool,
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
        .timeout(std::time::Duration::from_secs(15))
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

    let args: Vec<&str> = vec![api_key, base_url, model_name];

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
    // 检测 Node.js
    let (node_installed, node_version) = match Command::new("node").arg("--version").output() {
        Ok(output) if output.status.success() => {
            let ver = String::from_utf8_lossy(&output.stdout).trim().to_string();
            (true, ver)
        }
        _ => (false, "未安装".to_string()),
    };

    // 检测 npm
    let (npm_installed, npm_version) = match Command::new("npm").arg("--version").output() {
        Ok(output) if output.status.success() => {
            let ver = String::from_utf8_lossy(&output.stdout).trim().to_string();
            (true, ver)
        }
        _ => (false, "未安装".to_string()),
    };

    // 检测 Claude Code CLI
    let (claude_installed, claude_version) = match Command::new("claude").arg("--version").output() {
        Ok(output) if output.status.success() => {
            let ver = String::from_utf8_lossy(&output.stdout).trim().to_string();
            (true, ver)
        }
        _ => (false, "未安装".to_string()),
    };

    // 检测环境变量是否已配置
    let env_configured = check_env_configured();

    Ok(EnvironmentStatus {
        node_installed,
        node_version,
        npm_installed,
        npm_version,
        claude_installed,
        claude_version,
        env_configured,
    })
}

fn check_env_configured() -> bool {
    // 检查 Windows 用户环境变量
    if cfg!(target_os = "windows") {
        if let Ok(val) = std::env::var("ANTHROPIC_AUTH_TOKEN") {
            return !val.is_empty();
        }
        return false;
    }

    // macOS：检查 shell profile 中是否有 AIEnvKit 配置块
    let shell_profile = get_shell_profile();
    if let Ok(content) = std::fs::read_to_string(shell_profile) {
        return content.contains("# AIEnvKit auto-generated config");
    }
    false
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
async fn open_node_download_page(app: tauri::AppHandle) -> Result<(), String> {
    let shell = app.shell();
    shell
        .open("https://nodejs.org/", None)
        .map_err(|e| format!("打开下载页面失败: {}", e))?;
    Ok(())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_dialog::init())
        .invoke_handler(tauri::generate_handler![
            test_connection,
            execute_configure,
            restore_backup,
            get_claude_path,
            check_environment,
            open_node_download_page,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
