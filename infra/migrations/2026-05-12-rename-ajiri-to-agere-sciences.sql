-- Rename stale Ajiri tenant to live AgereSciences tenant.
-- Safe/idempotent for existing Twlv20 production DB.

UPDATE tenants
SET slug = 'agere-sciences', name = 'AgereSciences'
WHERE slug = 'ajiri';

UPDATE tenants
SET name = 'AgereSciences'
WHERE slug = 'agere-sciences';
