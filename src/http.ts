export const json = (body: unknown, status = 200) => Response.json(body, { status });

export const isStr = (v: unknown, max: number): v is string => typeof v === "string" && v.length > 0 && v.length <= max;

export async function readJson(req: Request): Promise<Record<string, unknown> | null> {
	try {
		const body = await req.json();
		return body && typeof body === "object" ? (body as Record<string, unknown>) : null;
	} catch {
		return null;
	}
}
