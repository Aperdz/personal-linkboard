'use client';
// Client component: needs useState/onClick, so it must opt out of
// Next.js's default server-rendering behavior with 'use client'.
// This distinction (server vs client components) is a good talking
// point in the presentation — it's the headline feature of the
// Next.js App Router.

import { useState } from 'react';

const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:4000';

type ShortenResult = {
  shortCode: string;
  shortUrl: string;
  originalUrl: string;
};

export default function Home() {
  const [url, setUrl] = useState('');
  const [result, setResult] = useState<ShortenResult | null>(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [clickCount, setClickCount] = useState<number | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError('');
    setResult(null);
    setClickCount(null);
    setLoading(true);
    try {
      const res = await fetch(`${API_URL}/api/shorten`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ url }),
      });
      if (!res.ok) {
        const body = await res.json().catch(() => ({}));
        throw new Error(body.message?.[0] || body.message || 'Failed to shorten URL');
      }
      const data: ShortenResult = await res.json();
      setResult(data);
    } catch (err: any) {
      setError(err.message || 'Something went wrong');
    } finally {
      setLoading(false);
    }
  }

  async function refreshStats() {
    if (!result) return;
    const res = await fetch(`${API_URL}/api/stats/${result.shortCode}`);
    if (res.ok) {
      const data = await res.json();
      setClickCount(data.clickCount);
    }
  }

  return (
    <main>
      <h1>LinkBoard</h1>
      <p className="subtitle">Paste a URL, get a short link, watch the clicks roll in.</p>

      <form onSubmit={handleSubmit}>
        <input
          type="text"
          placeholder="https://example.com/some/long/page"
          value={url}
          onChange={(e) => setUrl(e.target.value)}
          required
        />
        <button type="submit" disabled={loading}>
          {loading ? 'Shortening...' : 'Shorten'}
        </button>
      </form>

      {error && <p className="error">{error}</p>}

      {result && (
        <div className="result">
          <p>
            <strong>Short URL:</strong>{' '}
            <a href={`${API_URL}/${result.shortCode}`} target="_blank" rel="noreferrer">
              {result.shortUrl}
            </a>
          </p>
          <p><strong>Original:</strong> {result.originalUrl}</p>
          <button onClick={refreshStats}>Refresh click count</button>
          {clickCount !== null && (
            <p><strong>Clicks so far:</strong> {clickCount}</p>
          )}
        </div>
      )}
    </main>
  );
}
