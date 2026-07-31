/**
 * Country service — all database access for country_access table.
 * Controls which countries may register, log in, play, recharge, etc.
 */

import { pool } from "../db/index.js";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface CountryAccessRow {
  iso2: string;
  name: string;
  dial_code: string;
  phone_example: string;
  is_allowed: boolean;
  allow_registration: boolean;
  allow_login: boolean;
  allow_gameplay: boolean;
  allow_recharge: boolean;
  allow_withdraw: boolean;
  allow_tournament: boolean;
  updated_at: Date;
}

export type CountryFeature =
  | "registration"
  | "login"
  | "gameplay"
  | "recharge"
  | "withdraw"
  | "tournament";

export interface UpdateCountryInput {
  name?: string;
  dial_code?: string;
  phone_example?: string;
  is_allowed?: boolean;
  allow_registration?: boolean;
  allow_login?: boolean;
  allow_gameplay?: boolean;
  allow_recharge?: boolean;
  allow_withdraw?: boolean;
  allow_tournament?: boolean;
}

// ---------------------------------------------------------------------------
// Queries
// ---------------------------------------------------------------------------

/**
 * Return all countries ordered alphabetically by name.
 * Returns an empty array if the database is unavailable.
 */
export async function listCountries(): Promise<CountryAccessRow[]> {
  if (!pool) return [];
  const { rows } = await pool.query<CountryAccessRow>(
    "SELECT * FROM country_access ORDER BY name ASC",
  );
  return rows;
}

/**
 * Find a country by its ISO2 code (case-insensitive).
 * Returns null when not found or database is unavailable.
 */
export async function getCountry(iso2: string): Promise<CountryAccessRow | null> {
  if (!pool) return null;
  const { rows } = await pool.query<CountryAccessRow>(
    "SELECT * FROM country_access WHERE iso2 = $1 LIMIT 1",
    [iso2.toUpperCase()],
  );
  return rows[0] ?? null;
}

/**
 * Update an existing country's access settings.
 * Returns the updated row, or null if the country was not found.
 */
export async function updateCountry(
  iso2: string,
  input: UpdateCountryInput,
): Promise<CountryAccessRow | null> {
  if (!pool) throw new Error("Database is not available.");

  const sets: string[] = [];
  const values: unknown[] = [];
  let idx = 1;

  const fieldMap: Record<keyof UpdateCountryInput, string> = {
    name: "name",
    dial_code: "dial_code",
    phone_example: "phone_example",
    is_allowed: "is_allowed",
    allow_registration: "allow_registration",
    allow_login: "allow_login",
    allow_gameplay: "allow_gameplay",
    allow_recharge: "allow_recharge",
    allow_withdraw: "allow_withdraw",
    allow_tournament: "allow_tournament",
  };

  for (const [key, col] of Object.entries(fieldMap) as [keyof UpdateCountryInput, string][]) {
    if (input[key] !== undefined) {
      sets.push(`${col} = $${idx++}`);
      values.push(input[key]);
    }
  }

  if (sets.length === 0) return getCountry(iso2);

  sets.push(`updated_at = NOW()`);
  values.push(iso2.toUpperCase());

  const { rows } = await pool.query<CountryAccessRow>(
    `UPDATE country_access SET ${sets.join(", ")} WHERE iso2 = $${idx} RETURNING *`,
    values,
  );
  return rows[0] ?? null;
}

/**
 * Check whether a country is permitted for a specific feature.
 *
 * Returns:
 * - `{ allowed: true }` when the country is allowed and the feature is enabled.
 * - `{ allowed: false, message: string }` when blocked (whole country or specific feature).
 * - `{ allowed: true }` when the country is not found in the table (fail-open for
 *   unknown countries so new countries aren't inadvertently blocked until seeded).
 */
export async function checkCountryAccess(
  iso2: string,
  feature: CountryFeature,
): Promise<{ allowed: true } | { allowed: false; message: string }> {
  const row = await getCountry(iso2);

  // Unknown country — fail open (admin hasn't configured it yet).
  if (!row) return { allowed: true };

  if (!row.is_allowed) {
    return {
      allowed: false,
      message:
        "This game is currently unavailable in your country due to local regulations.",
    };
  }

  const featureMap: Record<CountryFeature, boolean> = {
    registration: row.allow_registration,
    login: row.allow_login,
    gameplay: row.allow_gameplay,
    recharge: row.allow_recharge,
    withdraw: row.allow_withdraw,
    tournament: row.allow_tournament,
  };

  if (!featureMap[feature]) {
    return {
      allowed: false,
      message:
        "This game is currently unavailable in your country due to local regulations.",
    };
  }

  return { allowed: true };
}
