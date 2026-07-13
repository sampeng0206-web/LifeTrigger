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
			await sendEmail({
				to: toList,
				subject: "LifeTrigger - 安心守護通知信",
				body: trigger.encrypted_payload
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
					await sendEmail({
						to: toParam.split(",").map(e => e.trim()),
						subject: "LifeTrigger - 本地開發發送測試信",
						body: "<p>這是一封來自 LifeTrigger 本地開發環境的 Resend 測試郵件。</p>"
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

				await env.DB.prepare(`
					INSERT INTO cloud_triggers (id, encrypted_payload, recipient_emails, deadline, is_active, requires_cloud, status, created_at, updated_at)
					VALUES (?, ?, ?, ?, 1, 1, 'waiting', ?, ?)
				`).bind(
					id,
					"<p>這是一封安全的交代信件內容。當您收到這封信時，代表觸發條件已達成。</p>",
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
