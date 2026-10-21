/**
 * Strait setup for this app, exactly as a customer would configure it:
 * the link host and the workspace's publishable key (Dashboard → Get started).
 * Both can be changed at runtime in Settings.
 */
export const DEFAULT_ENDPOINT = 'https://strait-dev.strait.link';
export const DEFAULT_PUBLISHABLE_KEY = 'st_pub_live_62406c705fed406db90c1deeecdb183b';

/** Required by Google Play: linked from the store listing and from Settings. */
export const PRIVACY_POLICY_URL = 'https://strait-link.github.io/strait-demo-site/privacy.html';

/** Browser side of the fingerprint check (GitHub Pages, not the link domain). */
export const FINGERPRINT_PAGE = 'https://strait-link.github.io/strait-demo-site/fingerprint.html';
/** A browser page that shows a link to tap (for the "tap inside Chrome" tests). */
export const BROWSER_LINK_PAGE = 'https://strait-link.github.io/strait-demo-site/open.html';

/** Ready-made test links (workspace "strait-dev"), one per destination screen. */
export const TEST_LINKS: Array<{ slug: string; label: string; opens: string }> = [
  { slug: 'bl-product', label: 'Product link', opens: 'Product #42 (red)' },
  { slug: 'bl-category', label: 'Category link', opens: 'Shoes category' },
  { slug: 'bl-promo', label: 'Coupon link', opens: 'Applies DIWALI20, opens cart' },
  { slug: 'bl-order', label: 'Order link (needs login)', opens: 'Login, then order #1001' },
  { slug: 'bl-invite', label: 'Invite link', opens: 'Invite from ANU' },
  { slug: 'bl-unknown', label: 'Unknown page link', opens: '"Link not recognised" screen' },
  { slug: 'bl-expired', label: 'Expired link', opens: 'An "expired" message' },
];
