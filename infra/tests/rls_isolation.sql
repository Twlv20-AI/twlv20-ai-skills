-- RLS isolation smoke test for Twlv20 tenant-scoped tables.
-- Run as postgres/superuser after infra/schema.sql has been applied.

\set ON_ERROR_STOP on
\c twlv20

BEGIN;

SELECT id AS pure_peptide_tenant FROM tenants WHERE slug = 'pure-peptide' \gset
SELECT id AS ajiri_tenant FROM tenants WHERE slug = 'ajiri' \gset

SET LOCAL ROLE twlv20_app;

SELECT set_config('app.tenant_id', :'pure_peptide_tenant', false);
INSERT INTO runs (tenant_id, workflow, agent, trigger_source, outcome)
VALUES (:'pure_peptide_tenant', 'rls-isolation-test', 'sql-test', 'manual', 'pure-peptide-visible');

SELECT set_config('app.tenant_id', :'ajiri_tenant', false);
INSERT INTO runs (tenant_id, workflow, agent, trigger_source, outcome)
VALUES (:'ajiri_tenant', 'rls-isolation-test', 'sql-test', 'manual', 'ajiri-visible');

SELECT set_config('app.tenant_id', :'pure_peptide_tenant', false);
DO $$
BEGIN
  IF (SELECT count(*) FROM runs WHERE workflow = 'rls-isolation-test') <> 1 THEN
    RAISE EXCEPTION 'pure-peptide tenant saw wrong row count';
  END IF;
  IF EXISTS (SELECT 1 FROM runs WHERE outcome = 'ajiri-visible') THEN
    RAISE EXCEPTION 'pure-peptide tenant saw ajiri row';
  END IF;
END $$;

SELECT set_config('app.tenant_id', :'ajiri_tenant', false);
DO $$
BEGIN
  IF (SELECT count(*) FROM runs WHERE workflow = 'rls-isolation-test') <> 1 THEN
    RAISE EXCEPTION 'ajiri tenant saw wrong row count';
  END IF;
  IF EXISTS (SELECT 1 FROM runs WHERE outcome = 'pure-peptide-visible') THEN
    RAISE EXCEPTION 'ajiri tenant saw pure-peptide row';
  END IF;
END $$;

SELECT set_config('app.tenant_id', '', false);
DO $$
BEGIN
  IF (SELECT count(*) FROM runs WHERE workflow = 'rls-isolation-test') <> 0 THEN
    RAISE EXCEPTION 'empty app.tenant_id should fail closed';
  END IF;
END $$;

RESET ROLE;
ROLLBACK;

SELECT 'RLS isolation test passed' AS result;
