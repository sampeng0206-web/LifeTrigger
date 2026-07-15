import { sendEmail } from "./email";
import { encryptText, decryptText } from "./crypto";

export interface Env {
	DB: D1Database;
	RESEND_API_KEY: string;
	ENVIRONMENT?: string;
	API_KEY?: string;
	ENCRYPTION_KEY?: string;
	REVENUECAT_API_KEY?: string;
}

interface TriggerRow {
	id: string;
	user_id: string;
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
 * 驗證 RevenueCat 使用者是否有 cloud_guardian 訂閱權限
 */
async function checkUserEntitlement(userId: string, env: Env): Promise<boolean> {
	const revenueCatApiKey = env.REVENUECAT_API_KEY;
	if (!revenueCatApiKey) {
		if (env.ENVIRONMENT === "development") {
			console.warn("REVENUECAT_API_KEY is not configured in development. Bypassing entitlement check.");
			return true;
		}
		console.error("REVENUECAT_API_KEY is missing in production!");
		return false;
	}

	try {
		const encodedUserId = encodeURIComponent(userId);
		const url = `https://api.revenuecat.com/v1/subscribers/${encodedUserId}`;
		
		const response = await fetch(url, {
			method: "GET",
			headers: {
				"Authorization": `Bearer ${revenueCatApiKey}`,
				"Content-Type": "application/json"
			}
		});
		
		if (!response.ok) {
			console.error(`RevenueCat verification failed with status: ${response.status}`);
			return false;
		}
		
		const data: any = await response.json();
		const entitlement = data.subscriber?.entitlements?.cloud_guardian;
		if (!entitlement) {
			console.warn(`User ${userId} does not have cloud_guardian entitlement.`);
			return false;
		}
		
		if (entitlement.expires_date) {
			const expiry = new Date(entitlement.expires_date);
			if (expiry < new Date()) {
				console.warn(`User ${userId} cloud_guardian entitlement has expired.`);
				return false;
			}
		}
		return true;
	} catch (e) {
		console.error(`Error verifying RevenueCat entitlement for user ${userId}:`, e);
		return false;
	}
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
			// B. 解密
			let payloadText = trigger.encrypted_payload;
			if (env.ENCRYPTION_KEY) {
				try {
					payloadText = await decryptText(trigger.encrypted_payload, env.ENCRYPTION_KEY);
				} catch (decErr) {
					console.error(`${logPrefix} Decryption failed, using fallback raw payload:`, decErr);
				}
			}

			// C. 發信
			const toList = trigger.recipient_emails.split(",").map(e => e.trim());
			const { subject, bodyHtml } = generateEmailHtml(payloadText);

			await sendEmail({
				to: toList,
				subject: subject,
				body: bodyHtml
			}, env);

			// D. 寄信成功：狀態更新為 'delivered'
			await env.DB.prepare(`
				UPDATE cloud_triggers 
				SET status = 'delivered', updated_at = ? 
				WHERE id = ?
			`).bind(new Date().toISOString(), trigger.id).run();
			console.log(`${logPrefix} Email sent successfully. Status set to 'delivered'.`);
			succeeded++;
		} catch (error: any) {
			// E. 寄信失敗：狀態更新為 'failed'
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

		// API 認證機制安全檢查 (針對所有以 /api/ 開頭的路由)
		if (url.pathname.startsWith("/api/")) {
			const expectedApiKey = env.API_KEY;
			if (expectedApiKey) {
				const clientApiKey = request.headers.get("X-API-Key");
				if (clientApiKey !== expectedApiKey) {
					return new Response(JSON.stringify({ error: "Unauthorized" }), {
						status: 401,
						headers: { "Content-Type": "application/json" }
					});
				}
			}

			// POST /api/triggers: 上傳 / 更新 Trigger
			if (url.pathname === "/api/triggers" && request.method === "POST") {
				try {
					const body: any = await request.json();
					const { id, user_id, recipient_emails, deadline, is_active, requires_cloud, status, payload } = body;

					if (!id || !user_id || !recipient_emails || !deadline || !payload) {
						return new Response(JSON.stringify({ error: "Missing required fields" }), {
							status: 400,
							headers: { "Content-Type": "application/json" }
						});
					}

					// 線上校驗訂閱權限
					const hasEntitlement = await checkUserEntitlement(user_id, env);
					if (!hasEntitlement) {
						return new Response(JSON.stringify({ error: "Forbidden: Active cloud_guardian subscription required" }), {
							status: 403,
							headers: { "Content-Type": "application/json" }
						});
					}

					// 金鑰加密 payload
					let encryptedPayload = JSON.stringify(payload);
					if (env.ENCRYPTION_KEY) {
						encryptedPayload = await encryptText(encryptedPayload, env.ENCRYPTION_KEY);
					}

					const now = new Date().toISOString();
					const isActiveVal = is_active !== undefined ? is_active : 1;
					const requiresCloudVal = requires_cloud !== undefined ? requires_cloud : 1;
					const statusVal = status || "waiting";

					await env.DB.prepare(`
						INSERT OR REPLACE INTO cloud_triggers (
							id, user_id, encrypted_payload, recipient_emails, deadline,
							is_active, requires_cloud, status, created_at, updated_at
						) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
					`).bind(
						id,
						user_id,
						encryptedPayload,
						recipient_emails,
						deadline,
						isActiveVal,
						requiresCloudVal,
						statusVal,
						now,
						now
					).run();

					return new Response(JSON.stringify({ success: true, message: "Trigger saved successfully" }), {
						status: 200,
						headers: { "Content-Type": "application/json" }
					});
				} catch (err: any) {
					return new Response(JSON.stringify({ error: `Internal Server Error: ${err.message}` }), {
						status: 500,
						headers: { "Content-Type": "application/json" }
					});
				}
			}

			// GET /api/triggers/restore: 還原多端資料
			if (url.pathname === "/api/triggers/restore" && request.method === "GET") {
				try {
					const userId = url.searchParams.get("user_id");
					if (!userId) {
						return new Response(JSON.stringify({ error: "Missing 'user_id' parameter" }), {
							status: 400,
							headers: { "Content-Type": "application/json" }
						});
					}

					// 線上校驗訂閱權限
					const hasEntitlement = await checkUserEntitlement(userId, env);
					if (!hasEntitlement) {
						return new Response(JSON.stringify({ error: "Forbidden: Active cloud_guardian subscription required" }), {
							status: 403,
							headers: { "Content-Type": "application/json" }
						});
					}

					// 查詢該使用者底下所有 active 的 triggers
					const { results } = await env.DB.prepare(`
						SELECT * FROM cloud_triggers 
						WHERE user_id = ? AND is_active = 1
					`).bind(userId).all<TriggerRow>();

					const restoredTriggers = [];
					for (const row of results) {
						let decryptedPayload = row.encrypted_payload;
						if (env.ENCRYPTION_KEY) {
							try {
								decryptedPayload = await decryptText(row.encrypted_payload, env.ENCRYPTION_KEY);
							} catch (decErr) {
								console.error(`Failed to decrypt for restore on trigger ${row.id}:`, decErr);
							}
						}

						let payloadObj = { message: decryptedPayload, shared_memory: "" };
						try {
							payloadObj = JSON.parse(decryptedPayload);
						} catch (e) {
							// 舊格式或純文字
						}

						restoredTriggers.push({
							id: row.id,
							user_id: row.user_id,
							recipient_emails: row.recipient_emails,
							deadline: row.deadline,
							is_active: row.is_active,
							requires_cloud: row.requires_cloud,
							status: row.status,
							payload: payloadObj,
							created_at: row.created_at,
							updated_at: row.updated_at
						});
					}

					return new Response(JSON.stringify({ success: true, triggers: restoredTriggers }), {
						status: 200,
						headers: { "Content-Type": "application/json" }
					});
				} catch (err: any) {
					return new Response(JSON.stringify({ error: `Internal Server Error: ${err.message}` }), {
						status: 500,
						headers: { "Content-Type": "application/json" }
					});
				}
			}
		}

		// 開發模式專屬測試路由
		if (url.pathname === "/test-email" || url.pathname === "/add-test-trigger" || url.pathname === "/trigger-cron") {
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
				const userId = url.searchParams.get("user_id") || "test-user-id";
				if (!email) {
					return new Response("Missing 'email' parameter", { status: 400 });
				}
				const id = crypto.randomUUID();
				const deadline = new Date(Date.now() + offset * 1000).toISOString();
				const now = new Date().toISOString();

				const testPayload = JSON.stringify({
					message: "這是一封為測試排程與狀態機所建立的守護信件內容。請忽略此訊息。",
					shared_memory: "我們是在大學迎新晚會認識的"
				});

				let encryptedPayload = testPayload;
				if (env.ENCRYPTION_KEY) {
					encryptedPayload = await encryptText(testPayload, env.ENCRYPTION_KEY);
				}

				await env.DB.prepare(`
					INSERT INTO cloud_triggers (id, user_id, encrypted_payload, recipient_emails, deadline, is_active, requires_cloud, status, created_at, updated_at)
					VALUES (?, ?, ?, ?, ?, 1, 1, 'waiting', ?, ?)
				`).bind(
					id,
					userId,
					encryptedPayload,
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
