-- ad_login_examples.sql
-- Postgres SQL – Fluxos de Login com Active Directory (AD)
-- Pré-requisitos do schema:
--   - Tabela "user" (id, primary_name, last_name, email, last_access, is_active, is_deleted, ...)
--   - Tabela ad_user (id, email UNIQUE, ad_group, is_linked, user_id FK -> user.id, creation_date, modification_date)
--   - Tabelas de autorização: "group", user_group, features, permission (group_id -> features_id)
-- Observação: Este arquivo contém 3 exemplos completos (com transação) e consultas auxiliares.
-- Ajustar os valores do CTE `params` (email e ad_group recebidos do provedor AD) conforme necessário para testes.

/* ===============================================================
   EXEMPLO 1: LOGIN BEM-SUCEDIDO (Usuário já vinculado ao AD e no grupo correto)
   Cenário:
     - O usuário existe na plataforma (tabela "user") e está ativo.
     - Já possui vínculo em ad_user.is_linked = true.
     - O grupo enviado pelo AD corresponde ao grupo exigido para acesso.
   Efeitos:
     - Atualiza last_access do usuário.
     - Retorna perfil (dados do usuário) + grupos + permissões efetivas (features).
   =============================================================== */
BEGIN;

-- Parâmetros de entrada (simulação)
WITH params AS (
  SELECT
    'ana.silva@example.com'::varchar AS email_in,
    'CorpPlatformAccess'::varchar    AS ad_group_in
),
required AS (
  SELECT 'CorpPlatformAccess'::varchar AS required_ad_group
),
ad_check AS (
  -- 1) Verifica vínculo AD + igualdade do grupo exigido
  SELECT a.*, u.primary_name, u.last_name, u.is_active, u.is_deleted
  FROM ad_user a
  JOIN "user" u ON u.id = a.user_id
  CROSS JOIN required r
  CROSS JOIN params p
  WHERE a.email = p.email_in
    AND a.is_linked = TRUE
    AND a.ad_group = r.required_ad_group
),
updated AS (
  -- 2) Atualiza last_access se todas as condições forem satisfeitas
  UPDATE "user" u
  SET last_access = NOW(), modification_date = NOW()
  FROM ad_check c
  WHERE u.id = c.user_id
    AND u.is_active = TRUE
    AND u.is_deleted = FALSE
  RETURNING u.id AS user_id
)
-- 3) Retorna o "perfil" do usuário com grupos e permissões (features)
SELECT
  u.id,
  u.primary_name,
  u.last_name,
  u.email,
  array_agg(DISTINCT g.name)               AS groups,
  array_agg(DISTINCT f.feature_key)        AS features
FROM updated upd
JOIN "user" u            ON u.id = upd.user_id
LEFT JOIN user_group ug  ON ug.user_id = u.id
LEFT JOIN "group" g      ON g.id = ug.group_id
LEFT JOIN "permission" p ON p.group_id = g.id
LEFT JOIN features f     ON f.id = p.features_id
GROUP BY u.id, u.primary_name, u.last_name, u.email;

COMMIT;



/* ===============================================================
   EXEMPLO 2: PRIMEIRO LOGIN (Usuário cadastrado, mas AINDA NÃO vinculado ao AD)
   Cenário:
     - O usuário já existe em "user" e está ativo.
     - Não há registro em ad_user ou está com is_linked = false.
     - O grupo recebido do AD é o exigido.
   Efeitos:
     - Cria/atualiza o vínculo em ad_user com is_linked = true e associa ao user_id.
     - Atualiza last_access.
     - Retorna o perfil do usuário (sem alterar grupos/permissões).
   =============================================================== */
BEGIN;

WITH params AS (
  SELECT
    'bruno.costa@example.com'::varchar AS email_in,
    'CorpPlatformAccess'::varchar      AS ad_group_in
),
required AS (
  SELECT 'CorpPlatformAccess'::varchar AS required_ad_group
),
the_user AS (
  -- 1) Garante que o usuário existe e está ativo (NÃO criar automaticamente)
  SELECT u.*
  FROM "user" u
  JOIN params p ON p.email_in = u.email
  WHERE u.is_active = TRUE AND u.is_deleted = FALSE
),
upsert_ad AS (
  -- 2) Vincula/atualiza o ad_user (UPSERT por email)
  INSERT INTO ad_user (email, ad_group, is_linked, user_id)
  SELECT p.email_in, r.required_ad_group, TRUE, u.id
  FROM params p, required r, the_user u
  ON CONFLICT (email) DO UPDATE
    SET ad_group = EXCLUDED.ad_group,
        is_linked = TRUE,
        user_id = EXCLUDED.user_id,
        modification_date = NOW()
  RETURNING user_id
),
updated AS (
  -- 3) Atualiza last_access
  UPDATE "user" u
  SET last_access = NOW(), modification_date = NOW()
  FROM upsert_ad ua
  WHERE u.id = ua.user_id
  RETURNING u.id
)
-- 4) Retorna o perfil básico
SELECT u.id, u.primary_name, u.last_name, u.email, u.last_access
FROM "user" u
JOIN updated x ON x.id = u.id;

COMMIT;



/* ===============================================================
   EXEMPLO 3: LOGIN NEGADO (Usuário sem cadastro OU grupo AD inválido)
   Cenário:
     - O usuário não existe na plataforma OU
     - Está inativo/deletado OU
     - O grupo do AD não corresponde ao grupo exigido.
   Efeitos:
     - Nenhuma atualização. Retorna diagnósticos para auditoria.
   =============================================================== */
-- Observação: este exemplo NÃO abre transação, pois não há mutações.
WITH params AS (
  SELECT
    'fernanda.lima@example.com'::varchar AS email_in,
    'CorpUsers'::varchar                 AS ad_group_in       -- <- grupo errado para ilustrar falha
),
required AS (
  SELECT 'CorpPlatformAccess'::varchar AS required_ad_group
),
user_lookup AS (
  SELECT u.*
  FROM "user" u
  JOIN params p ON p.email_in = u.email
),
ad_lookup AS (
  SELECT a.*
  FROM ad_user a
  JOIN params p ON p.email_in = a.email
),
diagnostics AS (
  SELECT
    (SELECT COUNT(*) FROM user_lookup) > 0         AS user_exists,
    (SELECT COUNT(*) FROM user_lookup WHERE is_active = TRUE AND is_deleted = FALSE) > 0 AS user_is_active,
    (SELECT COUNT(*) FROM ad_lookup WHERE is_linked = TRUE) > 0 AS ad_is_linked,
    (SELECT COUNT(*) FROM ad_lookup a, required r WHERE a.ad_group = r.required_ad_group) > 0 AS ad_group_ok
)
SELECT
  CASE
    WHEN NOT user_exists THEN 'FAIL: Usuário não cadastrado na plataforma'
    WHEN NOT user_is_active THEN 'FAIL: Usuário inativo ou marcado como deletado'
    WHEN NOT ad_is_linked THEN 'FAIL: Usuário não está vinculado ao AD (is_linked = false ou sem registro)'
    WHEN NOT ad_group_ok THEN 'FAIL: Grupo do AD não autorizado para acesso'
    ELSE 'OK'
  END AS status,
  *
FROM diagnostics;



/* ===============================================================
   CONSULTAS AUXILIARES (para depuração/relatórios)
   =============================================================== */

-- A) Ver usuários e seus vínculos AD
SELECT a.email, a.ad_group, a.is_linked, u.id AS user_id, u.primary_name, u.last_name, u.is_active, u.is_deleted
FROM ad_user a
LEFT JOIN "user" u ON u.id = a.user_id;

-- B) Ver permissões efetivas (features) por usuário via grupos
--    (cada feature habilitada ao(s) grupo(s) do usuário)
SELECT
  u.email,
  g.name AS group_name,
  f.feature_key
FROM "user" u
JOIN user_group ug  ON ug.user_id = u.id
JOIN "group" g      ON g.id = ug.group_id
JOIN "permission" p ON p.group_id = g.id
JOIN features f     ON f.id = p.features_id
ORDER BY u.email, g.name, f.feature_key;

-- C) Ver papeis atribuídos (roles) por usuário (se aplicável)
SELECT u.email, r.name AS role_name
FROM "user" u
JOIN user_roles ur ON ur.user_id = u.id
JOIN roles r       ON r.id = ur.roles_id
ORDER BY u.email, r.name;

