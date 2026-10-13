import { applyD1Migrations } from "cloudflare:test";
import { env } from "cloudflare:workers";

interface TestEnv extends Env {
  TEST_MIGRATIONS: { name: string; queries: string[] }[];
}

await applyD1Migrations(env.DB, (env as TestEnv).TEST_MIGRATIONS);
