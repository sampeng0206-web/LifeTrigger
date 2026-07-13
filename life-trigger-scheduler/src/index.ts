import { sendEmail } from "./email";

export interface Env {
	DB: D1Database;
	RESEND_API_KEY: string;
	ENVIRONMENT?: string;
}

interface TriggerRow {
	id: string;
	encrypted_payload: string;
	recipient_emails: string;
	deadline: string;
	is_active: number;
	requires_cloud: number;
	status: string;
	created_at: string;
	updated_at: string;
}

/**
 * 依據 payload 解析與渲染中性主旨與 HTML 信件內容
 */
function generateEmailHtml(payloadText: string): { subject: string; bodyHtml: string } {
	let message = payloadText;
	let sharedMemory = "";

	try {
		const parsed = JSON.parse(payloadText);
		if (parsed && typeof parsed === "object") {
			message = parsed.message || "";
			sharedMemory = parsed.shared_memory || "";
		}
	} catch (e) {
		// 支援舊格式或純文字 payload
	}

	const subject = "【安心守護】您有一封重要通知信件";
	
	const sharedMemoryBlock = sharedMemory
		? `
		<div style="background-color: #f0f7ff; border-left: 4px solid #0070f3; padding: 15px; border-radius: 4px; margin: 20px 0;">
			<strong style="color: #0070f3; display: block; margin-bottom: 5px;">🔑 只有您與設定者知道的共同回憶（身分驗證）：</strong>
			<span style="color: #333; font-style: italic;">「 ${sharedMemory} 」</span>
		</div>
		`
		: "";

	const bodyHtml = `
		<div style="font-family: sans-serif; padding: 20px; line-height: 1.6; max-width: 600px; margin: 0 auto; border: 1px solid #eee; border-radius: 12px; background-color: #ffffff;">
			<h2 style="color: #1a1a1a; margin-top: 0; font-size: 20px;">🛡️ 安心守護 — 預置通知信件</h2>
			<p style="color: #666; font-size: 14px;">這是一封由設定者預先安排並啟動的守護信件。</p>
			${sharedMemoryBlock}
			<div style="background-color: #fafafa; border: 1px solid #eaeaea; padding: 20px; border-radius: 8px; margin-top: 20px;">
				<strong style="color: #444; display: block; margin-bottom: 10px;">✉️ 通知信件內容：</strong>
				<p style="color: #111; margin: 0; white-space: pre-wrap; font-size: 15px;">${message}</p>
			</div>
		</div>
	`;

	return { subject, bodyHtml };
}

/**
 * 處理過期的排程 Triggers
 */
async function processScheduledTriggers(env: Env): Promise<{ processed: number; succeeded: number; failed: number }> {
	const now = new Date().toISOString();

	// 1. 查詢所有狀態為 waiting 且 deadline 已到期的 cloud triggers
	const { results } = await env.DB.prepare(`
		SELECT * FROM cloud_triggers 
		WHERE is_active = 1 
			AND requires_cloud = 1 
			AND status = 'waiting' 
			AND deadline <= ?
	`).bind(now).all<TriggerRow>();

	let succeeded = 0;
	let failed = 0;

	for (const trigger of results) {
		const logPrefix = `[Trigger ID: ${trigger.id}]`;
		
		// A. 狀態立即先標記為 'triggered' (鎖定)，防止重複處理
		await env.DB.prepare(`
			UPDATE cloud_triggers 
			SET status = 'triggered', updated_at = ? 
			WHERE id = ?
		`).bind(now, trigger.id).run();
		console.log(`${logPrefix} Status locked to 'triggered'.`);

		try {
			// B. 發信
			const toList = trigger.recipient_emails.split(",").map(e => e.trim());
			const { subject, bodyHtml } = generateEmailHtml(trigger.encrypted_payload);

			await sendEmail({
				to: toList,
				subject: subject,
				body: bodyHtml
			}, env);

			// C. 寄信成功：狀態更新為 'delivered'
			await env.DB.prepare(`
				UPDATE cloud_triggers 
				SET status = 'delivered', updated_at = ? 
				WHERE id = ?
			`).bind(new Date().toISOString(), trigger.id).run();
			console.log(`${logPrefix} Email sent successfully. Status set to 'delivered'.`);
			succeeded++;
		} catch (error: any) {
			// D. 寄信失敗：狀態更新為 'failed'
			await env.DB.prepare(`
				UPDATE cloud_triggers 
				SET status = 'failed', updated_at = ? 
				WHERE id = ?
			`).bind(new Date().toISOString(), trigger.id).run();
			console.error(`${logPrefix} Failed to send email. Status set to 'failed'. Error:`, error);
			failed++;
		}
	}

	return {
		processed: results.length,
		succeeded,
		failed
	};
}

export default {
	async fetch(request, env, ctx): Promise<Response> {
		const url = new URL(request.url);

		// 開發模式專屬測試路由
		if (url.pathname === "/test-email" || url.pathname === "/add-test-trigger" || url.pathname === "/trigger-cron") {
			// 雙重安全閥：只有在環境變數明確為 'development' 時才開放
			if (env.ENVIRONMENT !== "development") {
				return new Response("Not Found", { status: 404 });
			}

			if (url.pathname === "/test-email") {
				const toParam = url.searchParams.get("to");
				if (!toParam) {
					return new Response("Missing 'to' parameter", { status: 400 });
				}
				try {
					const dummyPayload = JSON.stringify({
						message: "這是一封來自本地開發環境的安心守護測試信件內容。當您看到此內容時，表示系統運作一切正常。",
						shared_memory: "我們第一次出遊去了宜蘭礁溪泡溫泉"
					});
					const { subject, bodyHtml } = generateEmailHtml(dummyPayload);

					await sendEmail({
						to: toParam.split(",").map(e => e.trim()),
						subject: subject,
						body: bodyHtml
					}, env);
					return new Response("Test email sent successfully!");
				} catch (err: any) {
					return new Response(`Failed to send test email: ${err.message}`, { status: 500 });
				}
			}

			if (url.pathname === "/add-test-trigger") {
				const offset = parseInt(url.searchParams.get("deadlineOffset") || "0", 10);
				const email = url.searchParams.get("email");
				if (!email) {
					return new Response("Missing 'email' parameter", { status: 400 });
				}
				const id = crypto.randomUUID();
				const deadline = new Date(Date.now() + offset * 1000).toISOString();
				const now = new Date().toISOString();

				// 將 message 與 shared_memory 包裝為 JSON
				const testPayload = JSON.stringify({
					message: "這是一封為測試排程與狀態機所建立的守護信件內容。請忽略此訊息。",
					shared_memory: "我們是在大學迎新晚會認識的"
				});

				await env.DB.prepare(`
					INSERT INTO cloud_triggers (id, encrypted_payload, recipient_emails, deadline, is_active, requires_cloud, status, created_at, updated_at)
					VALUES (?, ?, ?, ?, 1, 1, 'waiting', ?, ?)
				`).bind(
					id,
					testPayload,
					email,
					deadline,
					now,
					now
				).run();

				return new Response(JSON.stringify({
					message: "Test trigger added successfully",
					trigger: { id, deadline, email }
				}), { headers: { "Content-Type": "application/json" } });
			}

			if (url.pathname === "/trigger-cron") {
				try {
					const result = await processScheduledTriggers(env);
					return new Response(JSON.stringify({ message: "Cron triggered manually", result }), {
						headers: { "Content-Type": "application/json" }
					});
				} catch (err: any) {
					return new Response(`Failed to trigger cron manually: ${err.message}`, { status: 500 });
				}
			}
		}

		// 既有的基本路由
		switch (url.pathname) {
			case "/message":
				return new Response(`Hello, World! Environment is: ${env.ENVIRONMENT}, Has API Key: ${!!env.RESEND_API_KEY}`);
			case "/random":
				return new Response(crypto.randomUUID());
			default:
				return new Response("Not Found", { status: 404 });
		}
	},

	async scheduled(controller, env, ctx): Promise<void> {
		ctx.waitUntil(processScheduledTriggers(env));
	}
} satisfies ExportedHandler<Env>;
