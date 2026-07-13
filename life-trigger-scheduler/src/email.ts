export interface SendEmailOptions {
  to: string[];
  subject: string;
  body: string;
}

/**
 * 集中化寄信函式 (Resend 整合)
 * 所有發送郵件的邏輯皆在此處完成，便於未來更換供應商。
 * API Key 自 Cloudflare Secrets (env.RESEND_API_KEY) 取得。
 */
export async function sendEmail(
  { to, subject, body }: SendEmailOptions,
  env: { RESEND_API_KEY: string }
): Promise<void> {
  const apiKey = env.RESEND_API_KEY;
  if (!apiKey) {
    throw new Error("Missing RESEND_API_KEY in environment secrets.");
  }

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: "安心守護通知 <onboarding@resend.dev>",
      to: to,
      subject: subject,
      html: body,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Failed to send email via Resend API (${response.status}): ${errorText}`);
  }
}
