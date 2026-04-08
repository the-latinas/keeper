export function getApiBaseUrl(): string {
  return (
    (import.meta.env.VITE_API_BASE_URL as string | undefined)?.trim() || "http://localhost:5216"
  ).replace(/\/$/, "");
}

export async function apiGetJson<T>(path: string, init?: RequestInit): Promise<T> {
  const url = `${getApiBaseUrl()}${path.startsWith("/") ? path : `/${path}`}`;
  const res = await fetch(url, { ...init, credentials: "omit" });
  if (!res.ok) {
    throw new Error(`Request failed: ${res.status} ${res.statusText}`);
  }
  return res.json() as Promise<T>;
}
