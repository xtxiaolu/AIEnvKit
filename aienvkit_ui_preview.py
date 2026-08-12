#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AIEnvKit UI 预览原型
功能：展示最终 UI 布局和交互样式（保存/测试逻辑为模拟）
"""

import tkinter as tk
from tkinter import ttk, scrolledtext, messagebox


class AIEnvKitUI:
    def __init__(self, root):
        self.root = root
        self.root.title("AIEnvKit")
        self.root.geometry("520x600")
        self.root.resizable(False, False)
        self.root.configure(bg="#0f172a")

        # 扩展服务商列表：名称 -> (推荐 API 地址前缀, 推荐默认模型)
        self.providers = {
            "Claude": ("https://api.anthropic.com", "claude-3-5-sonnet-20240620"),
            "OpenAI": ("https://api.openai.com/v1", "gpt-4o"),
            "Gemini": ("https://generativelanguage.googleapis.com", "gemini-1.5-pro"),
            "Kimi": ("https://api.moonshot.cn/v1", "kimi-k2.6"),
            "DeepSeek": ("https://api.deepseek.com/v1", "deepseek-chat"),
            "Ollama": ("http://localhost:11434/v1", "llama3.1"),
            "通义千问": ("https://dashscope.aliyuncs.com/compatible-mode/v1", "qwen-max"),
            "文心一言": ("https://qianfan.baidubce.com/v2", "ernie-4.0"),
            "Azure OpenAI": ("https://<your-resource>.openai.azure.com/openai/deployments/<deployment>", "gpt-4o"),
            "OpenRouter": ("https://openrouter.ai/api/v1", "openai/gpt-4o"),
        }
        self.api_key_visible = False

        self.build_header()
        self.build_form()
        self.build_buttons()
        self.build_log()

    def build_header(self):
        header = tk.Frame(self.root, bg="#0f172a", height=80)
        header.pack(fill="x", padx=20, pady=(20, 10))

        title = tk.Label(
            header,
            text="AIEnvKit",
            font=("SF Pro Display", 28, "bold"),
            bg="#0f172a",
            fg="#38bdf8",
        )
        title.pack()

        subtitle = tk.Label(
            header,
            text="AI 模型环境一键配置工具",
            font=("SF Pro Text", 12),
            bg="#0f172a",
            fg="#94a3b8",
        )
        subtitle.pack()

    def build_form(self):
        form = tk.Frame(self.root, bg="#0f172a")
        form.pack(fill="x", padx=24, pady=10)

        # Provider
        tk.Label(
            form, text="模型服务商", font=("SF Pro Text", 11),
            bg="#0f172a", fg="#e2e8f0", anchor="w"
        ).pack(fill="x", pady=(0, 6))

        self.provider_var = tk.StringVar(value="Kimi")
        self.provider_names = list(self.providers.keys())
        self.provider_var.trace_add("write", self.on_provider_changed)

        provider_combo = ttk.Combobox(
            form,
            textvariable=self.provider_var,
            values=self.provider_names,
            state="readonly",
            font=("SF Pro Text", 12),
            height=22,
        )
        provider_combo.pack(fill="x", ipady=4, pady=(0, 14))
        self.style_combobox(provider_combo)

        # Model Name
        tk.Label(
            form, text="模型名称", font=("SF Pro Text", 11),
            bg="#0f172a", fg="#e2e8f0", anchor="w"
        ).pack(fill="x", pady=(0, 6))

        self.model_entry = tk.Entry(
            form,
            font=("SF Pro Text", 12),
            bg="#1e293b",
            fg="#f8fafc",
            insertbackground="#f8fafc",
            relief="flat",
            highlightthickness=1,
            highlightcolor="#38bdf8",
            highlightbackground="#334155",
        )
        self.model_entry.insert(0, "kimi-k2.6")
        self.model_entry.pack(fill="x", ipady=8, pady=(0, 14))

        # API Base URL
        tk.Label(
            form, text="API 地址", font=("SF Pro Text", 11),
            bg="#0f172a", fg="#e2e8f0", anchor="w"
        ).pack(fill="x", pady=(0, 6))

        self.base_url_entry = tk.Entry(
            form,
            font=("SF Pro Text", 12),
            bg="#1e293b",
            fg="#f8fafc",
            insertbackground="#f8fafc",
            relief="flat",
            highlightthickness=1,
            highlightcolor="#38bdf8",
            highlightbackground="#334155",
        )
        self.base_url_entry.insert(0, "https://api.moonshot.cn/v1")
        self.base_url_entry.pack(fill="x", ipady=8, pady=(0, 14))

        # API Key
        tk.Label(
            form, text="API Key", font=("SF Pro Text", 11),
            bg="#0f172a", fg="#e2e8f0", anchor="w"
        ).pack(fill="x", pady=(0, 6))

        key_frame = tk.Frame(form, bg="#0f172a")
        key_frame.pack(fill="x", pady=(0, 4))

        self.api_key_entry = tk.Entry(
            key_frame,
            font=("SF Pro Text", 12),
            bg="#1e293b",
            fg="#f8fafc",
            insertbackground="#f8fafc",
            relief="flat",
            highlightthickness=1,
            highlightcolor="#38bdf8",
            highlightbackground="#334155",
            show="●",
        )
        self.api_key_entry.pack(side="left", fill="x", expand=True, ipady=8)

        self.eye_btn = tk.Button(
            key_frame,
            text="👁",
            font=("SF Pro Text", 10),
            bg="#334155",
            fg="#f8fafc",
            activebackground="#475569",
            activeforeground="#f8fafc",
            relief="flat",
            cursor="hand2",
            command=self.toggle_key_visibility,
        )
        self.eye_btn.pack(side="right", padx=(8, 0), ipadx=8, ipady=4)

    def build_buttons(self):
        btn_frame = tk.Frame(self.root, bg="#0f172a")
        btn_frame.pack(fill="x", padx=24, pady=(14, 10))

        # 测试按钮：用青色边框 + 白字，避免与背景融为一体
        self.test_btn = tk.Button(
            btn_frame,
            text="测试连接",
            font=("SF Pro Text", 12, "bold"),
            bg="#0f172a",
            fg="#ffffff",
            activebackground="#1e293b",
            activeforeground="#38bdf8",
            relief="solid",
            bd=1,
            highlightbackground="#38bdf8",
            highlightcolor="#38bdf8",
            highlightthickness=1,
            cursor="hand2",
            command=self.on_test,
        )
        self.test_btn.pack(side="left", fill="x", expand=True, ipady=8, padx=(0, 8))

        self.save_btn = tk.Button(
            btn_frame,
            text="保存配置",
            font=("SF Pro Text", 12, "bold"),
            bg="#38bdf8",
            fg="#0f172a",
            activebackground="#0ea5e9",
            activeforeground="#0f172a",
            relief="flat",
            cursor="hand2",
            command=self.on_save,
        )
        self.save_btn.pack(side="right", fill="x", expand=True, ipady=8, padx=(8, 0))

    def build_log(self):
        log_frame = tk.Frame(self.root, bg="#0f172a")
        log_frame.pack(fill="both", expand=True, padx=24, pady=(10, 20))

        tk.Label(
            log_frame, text="执行日志", font=("SF Pro Text", 11, "bold"),
            bg="#0f172a", fg="#e2e8f0", anchor="w"
        ).pack(fill="x", pady=(0, 8))

        self.log_text = scrolledtext.ScrolledText(
            log_frame,
            font=("SF Mono", 10),
            bg="#1e293b",
            fg="#cbd5e1",
            insertbackground="#1e293b",
            relief="flat",
            height=12,
            state="disabled",
            wrap="word",
        )
        self.log_text.pack(fill="both", expand=True)

        self.log("🔍 等待操作...")
        self.log("💡 切换服务商会自动推荐 API 地址和模型名称")

    def style_combobox(self, combo):
        """美化 Combobox：字体更大、背景深色、箭头明显"""
        style = ttk.Style()
        style.theme_use("clam")
        style.configure(
            "TCombobox",
            fieldbackground="#1e293b",
            background="#1e293b",
            foreground="#f8fafc",
            arrowcolor="#38bdf8",
            bordercolor="#334155",
            darkcolor="#1e293b",
            lightcolor="#1e293b",
            padding=8,
        )
        style.map(
            "TCombobox",
            fieldbackground=[("readonly", "#1e293b")],
            selectbackground=[("readonly", "#38bdf8")],
            selectforeground=[("readonly", "#0f172a")],
        )

    def on_provider_changed(self, *args):
        """切换服务商时自动填充推荐 API 地址和模型"""
        provider = self.provider_var.get()
        if provider in self.providers:
            base_url, model = self.providers[provider]
            self.base_url_entry.delete(0, "end")
            self.base_url_entry.insert(0, base_url)
            self.model_entry.delete(0, "end")
            self.model_entry.insert(0, model)
            self.log(f"🔄 已切换至 {provider}，推荐地址/模型已自动填充")

    def log(self, message):
        self.log_text.configure(state="normal")
        self.log_text.insert("end", message + "\n")
        self.log_text.see("end")
        self.log_text.configure(state="disabled")
        self.root.update_idletasks()

    def toggle_key_visibility(self):
        if self.api_key_visible:
            self.api_key_entry.configure(show="●")
            self.api_key_visible = False
        else:
            self.api_key_entry.configure(show="")
            self.api_key_visible = True

    def get_inputs(self):
        return {
            "provider": self.provider_var.get(),
            "model": self.model_entry.get().strip(),
            "base_url": self.base_url_entry.get().strip(),
            "api_key": self.api_key_entry.get().strip(),
        }

    def on_test(self):
        data = self.get_inputs()
        if not data["api_key"]:
            messagebox.showwarning("提示", "请先输入 API Key")
            return
        if not data["base_url"]:
            messagebox.showwarning("提示", "请先输入 API 地址")
            return

        self.log(f"🔌 正在测试 {data['provider']} 连接...")
        self.test_btn.configure(state="disabled")
        self.root.after(1000, lambda: self.mock_test_result(data))

    def mock_test_result(self, data):
        # 模拟测试结果（实际版本会真实请求）
        if "xxx" in data["base_url"] or "<" in data["base_url"]:
            self.log("❌ 连接失败：API 地址中包含占位符，请替换为真实地址")
        else:
            self.log(f"✅ 连接成功！模型 {data['model']} 可正常访问")
        self.test_btn.configure(state="normal")

    def on_save(self):
        data = self.get_inputs()
        if not data["api_key"]:
            messagebox.showwarning("提示", "API Key 不能为空")
            return

        self.save_btn.configure(state="disabled")
        self.test_btn.configure(state="disabled")
        self.log("")
        self.log("🚀 开始一键配置...")

        steps = [
            "🔍 检测本地环境...",
            "📦 检查 Claude Code CLI...",
            "💾 创建配置备份...",
            "⚙️ 写入环境变量...",
            "📝 写入 Claude Code 配置...",
            "🔌 测试模型连接...",
        ]

        delay = 400
        for i, step in enumerate(steps):
            self.root.after(delay * (i + 1), lambda s=step: self.log(s))

        self.root.after(
            delay * (len(steps) + 1),
            lambda: self.finish_save(data),
        )

    def finish_save(self, data):
        if "xxx" in data["base_url"] or "<" in data["base_url"]:
            self.log("❌ 配置失败：API 地址中包含占位符")
        else:
            self.log("✅ 配置完成！")
            self.log("💡 请重新打开终端使环境变量生效")
        self.save_btn.configure(state="normal")
        self.test_btn.configure(state="normal")


def main():
    root = tk.Tk()
    try:
        root.tk.call("tk", "scaling", 1.2)
    except Exception:
        pass
    app = AIEnvKitUI(root)
    root.mainloop()


if __name__ == "__main__":
    main()
