import {
	env,
	createExecutionContext,
	waitOnExecutionContext,
	SELF,
} from "cloudflare:test";
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import worker from "../src";

describe("Hello World user worker", () => {
	describe("request for /message", () => {
		it('/ responds with "Hello, World!" (unit style)', async () => {
			const request = new Request<unknown, IncomingRequestCfProperties>(
				"http://example.com/message"
			);
			// Create an empty context to pass to `worker.fetch()`.
			const ctx = createExecutionContext();
			const response = await worker.fetch(request, env, ctx);
			// Wait for all `Promise`s passed to `ctx.waitUntil()` to settle before running test assertions
			await waitOnExecutionContext(ctx);
			expect(await response.text()).toMatchInlineSnapshot(`"Hello, World! Environment is: development, Has API Key: true"`);
		});

		it('responds with "Hello, World!" (integration style)', async () => {
			const request = new Request("http://example.com/message");
			const response = await SELF.fetch(request);
			expect(await response.text()).toMatchInlineSnapshot(`"Hello, World! Environment is: development, Has API Key: true"`);
		});
	});

	describe("request for /random", () => {
		it("/ responds with a random UUID (unit style)", async () => {
			const request = new Request<unknown, IncomingRequestCfProperties>(
				"http://example.com/random"
			);
			// Create an empty context to pass to `worker.fetch()`.
			const ctx = createExecutionContext();
			const response = await worker.fetch(request, env, ctx);
			// Wait for all `Promise`s passed to `ctx.waitUntil()` to settle before running test assertions
			await waitOnExecutionContext(ctx);
			expect(await response.text()).toMatch(
				/[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/
			);
		});

		it("responds with a random UUID (integration style)", async () => {
			const request = new Request("http://example.com/random");
			const response = await SELF.fetch(request);
			expect(await response.text()).toMatch(
				/[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/
			);
		});
	});

	describe("RevenueCat webhook endpoint", () => {
		let originalFetch: typeof fetch;

		beforeEach(() => {
			originalFetch = globalThis.fetch;
		});

		afterEach(() => {
			globalThis.fetch = originalFetch;
		});

		it("responds with success and ignores sandbox event", async () => {
			const payload = {
				event: {
					type: "RENEWAL",
					app_user_id: "test_sandbox_user",
					product_id: "lt_guard_annual",
					purchased_at_ms: 1782000000000,
					original_purchase_date_ms: 1782000000000,
					entitlement_ids: ["cloud_guardian"],
					environment: "SANDBOX"
				}
			};

			const request = new Request("http://example.com/api/revenuecat-webhook", {
				method: "POST",
				headers: {
					"Content-Type": "application/json",
					"Authorization": "Bearer test_webhook_secret"
				},
				body: JSON.stringify(payload)
			});

			const ctx = createExecutionContext();
			const response = await worker.fetch(request, env, ctx);
			await waitOnExecutionContext(ctx);

			expect(response.status).toBe(200);
			const body = await response.json() as any;
			expect(body.success).toBe(true);
			expect(body.message).toBe("Ignored sandbox event");
		});

		it("responds with success and sends email for production event", async () => {
			const payload = {
				event: {
					type: "RENEWAL",
					app_user_id: "test_prod_user",
					product_id: "lt_guard_annual",
					purchased_at_ms: 1782000000000,
					original_purchase_date_ms: 1782000000000,
					entitlement_ids: ["cloud_guardian"],
					environment: "PRODUCTION"
				}
			};

			const request = new Request("http://example.com/api/revenuecat-webhook", {
				method: "POST",
				headers: {
					"Content-Type": "application/json",
					"Authorization": "Bearer test_webhook_secret"
				},
				body: JSON.stringify(payload)
			});

			// Mock the Resend email API call
			const fetchMock = vi.fn().mockResolvedValue(new Response(JSON.stringify({ id: "mock_email_id" }), { status: 200 }));
			vi.stubGlobal("fetch", fetchMock);

			const ctx = createExecutionContext();
			const response = await worker.fetch(request, env, ctx);
			await waitOnExecutionContext(ctx);

			expect(response.status).toBe(200);
			const body = await response.json() as any;
			expect(body.success).toBe(true);
			expect(body.message).toBe("Email notification sent successfully");

			// Verify that the mock fetch was called to send email via Resend
			expect(fetchMock).toHaveBeenCalled();
			const [url, options] = fetchMock.mock.calls[0];
			expect(url).toBe("https://api.resend.com/emails");
			expect(options.method).toBe("POST");
			const emailPayload = JSON.parse(options.body);
			expect(emailPayload.to).toContain("sampeng0206@gmail.com");
			expect(emailPayload.subject).toContain("自動續訂");
		});
	});
});
