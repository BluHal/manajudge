// See https://svelte.dev/docs/kit/types#app.d.ts
// for information about these interfaces
import type { User } from '$lib/server/users';

declare global {
	namespace App {
		// interface Error {}
		interface Locals {
			/** Identità anonima device-scoped, presente quando la richiesta porta un device token. */
			user?: User;
		}
		// interface PageData {}
		// interface PageState {}
		// interface Platform {}
	}
}

export {};
