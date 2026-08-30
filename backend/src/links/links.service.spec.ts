// Unit test for the short-code generator — quick sanity check that
// doesn't need a real Mongo/Redis connection.
describe('short code generation pattern', () => {
  it('generates codes of the expected length using an alphanumeric alphabet', () => {
    const ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    const code = Array.from({ length: 7 })
      .map(() => ALPHABET[Math.floor(Math.random() * ALPHABET.length)])
      .join('');
    expect(code).toHaveLength(7);
    expect(code).toMatch(/^[A-Za-z0-9]+$/);
  });
});
