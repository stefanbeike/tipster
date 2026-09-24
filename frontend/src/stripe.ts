/** Public Stripe configuration. Never put the secret key in frontend code. */
declare global { interface ImportMeta { readonly env: Record<string, string | undefined> } }
export const stripePublishableKey: string = import.meta.env.VITE_STRIPE_PUBLISHABLE_KEY || ''
