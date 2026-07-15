async function getCryptoKey(secret: string): Promise<CryptoKey> {
	const encoder = new TextEncoder();
	const secretBytes = encoder.encode(secret);
	const hashBytes = await crypto.subtle.digest("SHA-256", secretBytes);
	return await crypto.subtle.importKey(
		"raw",
		hashBytes,
		{ name: "AES-GCM" },
		false,
		["encrypt", "decrypt"]
	);
}

export async function encryptText(text: string, secret: string): Promise<string> {
	const key = await getCryptoKey(secret);
	const encoder = new TextEncoder();
	const data = encoder.encode(text);
	const iv = crypto.getRandomValues(new Uint8Array(12));
	const encrypted = await crypto.subtle.encrypt(
		{ name: "AES-GCM", iv },
		key,
		data
	);

	const combined = new Uint8Array(iv.length + encrypted.byteLength);
	combined.set(iv, 0);
	combined.set(new Uint8Array(encrypted), iv.length);

	let binary = "";
	for (let i = 0; i < combined.byteLength; i++) {
		binary += String.fromCharCode(combined[i]);
	}
	return btoa(binary);
}

export async function decryptText(base64Ciphertext: string, secret: string): Promise<string> {
	const key = await getCryptoKey(secret);
	const binaryString = atob(base64Ciphertext);
	const combined = new Uint8Array(binaryString.length);
	for (let i = 0; i < binaryString.length; i++) {
		combined[i] = binaryString.charCodeAt(i);
	}

	const iv = combined.slice(0, 12);
	const ciphertext = combined.slice(12);

	const decrypted = await crypto.subtle.decrypt(
		{ name: "AES-GCM", iv },
		key,
		ciphertext
	);

	const decoder = new TextDecoder();
	return decoder.decode(decrypted);
}
