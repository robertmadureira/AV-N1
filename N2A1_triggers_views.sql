-- N2A1_triggers_views.sql
-- Atividade Avaliativa N2.A1 – Triggers e Views (PostgreSQL)
-- Este script considera o schema já implementado: "user", roles, modules, features_modules,
-- features, "group", "permission", user_roles, user_group, ad_user e funções anteriores.
-- Instruções do enunciado atendidas: procedimentos, gatilhos, tabela de auditoria, views e materializações.

/* ==========================================================================
   1) PROCEDURE pr_remover_dependencia_usuario (remove relacionamentos)
   ========================================================================== */
DROP PROCEDURE IF EXISTS pr_remover_dependencia_usuario(INT);
CREATE OR REPLACE PROCEDURE pr_remover_dependencia_usuario(p_user_id INT)
LANGUAGE plpgsql
AS $$
BEGIN
  -- Remove vínculos com papeis
  DELETE FROM user_roles WHERE user_id = p_user_id;

  -- Remove vínculos com grupos
  DELETE FROM user_group WHERE user_id = p_user_id;

  -- Remove vínculos com AD (se houver)
  DELETE FROM ad_user WHERE user_id = p_user_id;
END;
$$;

/* ==========================================================================
   2) TRIGGER tg_acionar_remocao_dependencia (antes de DELETE em "user")
      - Chama a procedure acima para limpar relacionamentos antes de excluir
   ========================================================================== */
DROP TRIGGER IF EXISTS tg_acionar_remocao_dependencia ON "user";
DROP FUNCTION IF EXISTS tgf_call_remover_dependencia_usuario();
CREATE OR REPLACE FUNCTION tgf_call_remover_dependencia_usuario()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  CALL pr_remover_dependencia_usuario(OLD.id);
  RETURN OLD; -- prossegue com o DELETE
END;
$$;

CREATE TRIGGER tg_acionar_remocao_dependencia
BEFORE DELETE ON "user"
FOR EACH ROW
EXECUTE FUNCTION tgf_call_remover_dependencia_usuario();

/* ==========================================================================
   3) Tabela de AUDITORIA e TRIGGER genérica para todas as tabelas
   ========================================================================== */
-- Tabela de auditoria
DROP TABLE IF EXISTS auditoria CASCADE;
CREATE TABLE auditoria (
  id BIGSERIAL PRIMARY KEY,
  ts TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  entidade TEXT NOT NULL,
  operacao TEXT NOT NULL,              -- 'INSERT' | 'UPDATE' | 'DELETE'
  usuario_bd TEXT DEFAULT CURRENT_USER,
  chave_primaria TEXT,                 -- opcional: PK afetada (quando identificável)
  detalhes JSONB                       -- opcional: diffs/snapshot parciais
);

-- Função de auditoria (row-level)
DROP FUNCTION IF EXISTS fn_auditar() CASCADE;
CREATE OR REPLACE FUNCTION fn_auditar()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_pk TEXT;
BEGIN
  -- Descobrir PK mais comum 'id' quando existir
  IF TG_OP IN ('INSERT','UPDATE') AND NEW IS NOT NULL THEN
    BEGIN
      v_pk := NEW.id::text;
    EXCEPTION WHEN OTHERS THEN
      v_pk := NULL;
    END;
  ELSIF TG_OP = 'DELETE' AND OLD IS NOT NULL THEN
    BEGIN
      v_pk := OLD.id::text;
    EXCEPTION WHEN OTHERS THEN
      v_pk := NULL;
    END;
  END IF;

  INSERT INTO auditoria (entidade, operacao, chave_primaria)
  VALUES (TG_TABLE_NAME, TG_OP, v_pk);

  RETURN COALESCE(NEW, OLD);
END;
$$;

-- Helper para criar triggers de auditoria
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT table_schema, table_name
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_type = 'BASE TABLE'
      AND table_name <> 'auditoria'
  LOOP
    EXECUTE format('
      DROP TRIGGER IF EXISTS tg_audit_%I ON %I;
      CREATE TRIGGER tg_audit_%I
      AFTER INSERT OR UPDATE OR DELETE ON %I
      FOR EACH ROW EXECUTE FUNCTION fn_auditar();
    ', r.table_name, r.table_name, r.table_name, r.table_name);
  END LOOP;
END $$;

/* ==========================================================================
   4) VIEW vw_consulta_usuario (Consulta de usuários – item 2 do Anexo)
      - Campos úteis para listagem: id, nome completo, e-mail, último acesso,
        tempo_desde_ultimo_acesso, ativo, deletado, qtde_grupos, qtde_papeis
   ========================================================================== */
DROP VIEW IF EXISTS vw_consulta_usuario CASCADE;
CREATE OR REPLACE VIEW vw_consulta_usuario AS
SELECT
  u.id,
  (COALESCE(u.primary_name,'') || ' ' || COALESCE(u.last_name,''))::text AS nome_completo,
  u.email,
  u.last_access,
  COALESCE(fu_formatar_tempo_acesso(u.last_access), 'N/D') AS tempo_desde_ultimo_acesso,
  u.is_active,
  u.is_deleted,
  COUNT(DISTINCT ug.group_id)  AS qtde_grupos,
  COUNT(DISTINCT ur.roles_id)  AS qtde_papeis
FROM "user" u
LEFT JOIN user_group ug ON ug.user_id = u.id
LEFT JOIN user_roles ur ON ur.user_id = u.id
GROUP BY u.id, u.primary_name, u.last_name, u.email, u.last_access, u.is_active, u.is_deleted;

/* ==========================================================================
   5) VIEW MATERIALIZADA vwm_consulta_usuario
      - Índice único para permitir REFRESH CONCURRENTLY
   ========================================================================== */
DROP MATERIALIZED VIEW IF EXISTS vwm_consulta_usuario CASCADE;
CREATE MATERIALIZED VIEW vwm_consulta_usuario AS
SELECT * FROM vw_consulta_usuario;

DROP INDEX IF EXISTS idx_vwm_consulta_usuario_pk;
CREATE UNIQUE INDEX idx_vwm_consulta_usuario_pk
  ON vwm_consulta_usuario (id);

/* ==========================================================================
   6) VIEW vw_consulta_grupo (Consulta de grupos – item 3 do Anexo)
      - Campos: id, nome do grupo, ativo/deletado, qtde_permissoes, qtde_usuarios
   ========================================================================== */
DROP VIEW IF EXISTS vw_consulta_grupo CASCADE;
CREATE OR REPLACE VIEW vw_consulta_grupo AS
SELECT
  g.id,
  g.name AS grupo,
  g.is_active,
  g.is_deleted,
  COUNT(DISTINCT p.id)          AS qtde_permissoes,
  COUNT(DISTINCT ug.user_id)    AS qtde_usuarios
FROM "group" g
LEFT JOIN "permission" p ON p.group_id = g.id
LEFT JOIN user_group ug  ON ug.group_id = g.id
WHERE g.is_deleted = FALSE
GROUP BY g.id, g.name, g.is_active, g.is_deleted;

/* ==========================================================================
   7) VIEW MATERIALIZADA vwm_consulta_grupo
   ========================================================================== */
DROP MATERIALIZED VIEW IF EXISTS vwm_consulta_grupo CASCADE;
CREATE MATERIALIZED VIEW vwm_consulta_grupo AS
SELECT * FROM vw_consulta_grupo;

DROP INDEX IF EXISTS idx_vwm_consulta_grupo_pk;
CREATE UNIQUE INDEX idx_vwm_consulta_grupo_pk
  ON vwm_consulta_grupo (id);

/* ==========================================================================
   8/10) VIEW vw_consulta_permissoes_grupo
         - Lista TODAS as funcionalidades e indica se o grupo possui (habilitada)
   ========================================================================== */
DROP VIEW IF EXISTS vw_consulta_permissoes_grupo CASCADE;
CREATE OR REPLACE VIEW vw_consulta_permissoes_grupo AS
SELECT
  g.id                          AS group_id,
  g.name                        AS grupo,
  f.id                          AS feature_id,
  f.feature_key                 AS funcionalidade,
  CASE WHEN p.id IS NOT NULL THEN TRUE ELSE FALSE END AS habilitada
FROM "group" g
CROSS JOIN features f
LEFT JOIN "permission" p
  ON p.group_id = g.id AND p.features_id = f.id
WHERE g.is_deleted = FALSE;

/* ==========================================================================
   11) VIEW MATERIALIZADA vwm_consulta_permissoes_grupo
   ========================================================================== */
DROP MATERIALIZED VIEW IF EXISTS vwm_consulta_permissoes_grupo CASCADE;
CREATE MATERIALIZED VIEW vwm_consulta_permissoes_grupo AS
SELECT * FROM vw_consulta_permissoes_grupo;

DROP INDEX IF EXISTS idx_vwm_consulta_permissoes_grupo_pk;
CREATE UNIQUE INDEX idx_vwm_consulta_permissoes_grupo_pk
  ON vwm_consulta_permissoes_grupo (group_id, feature_id);

/* ==========================================================================
   12) Duas alternativas para atualizar as MVs a cada 2 horas
       (A) Usando extensão pg_cron (recomendado)
       (B) Usando pgAgent (ou cron do SO + psql)
   ========================================================================== */

-- (A) pg_cron: agendar refresh a cada 2 horas (00:00, 02:00, ...)
-- Requer: CREATE EXTENSION pg_cron; e configuração adequada (cron.database_name)
-- Exemplos de jobs (ajuste o database_name conforme seu ambiente):
-- SELECT cron.schedule('mv_user_refresh_2h',
--                      '0 */2 * * *',
--                      $$REFRESH MATERIALIZED VIEW CONCURRENTLY vwm_consulta_usuario;
--                        REFRESH MATERIALIZED VIEW CONCURRENTLY vwm_consulta_grupo;
--                        REFRESH MATERIALIZED VIEW CONCURRENTLY vwm_consulta_permissoes_grupo;$$);

-- (B) pgAgent (ou cron do SO):
-- Exemplo usando cron do SO chamando psql a cada 2 horas:
-- 0 */2 * * * psql "host=localhost dbname=SEU_DB user=SEU_USER" -c "REFRESH MATERIALIZED VIEW CONCURRENTLY vwm_consulta_usuario; REFRESH MATERIALIZED VIEW CONCURRENTLY vwm_consulta_grupo; REFRESH MATERIALIZED VIEW CONCURRENTLY vwm_consulta_permissoes_grupo;"

-- Observação: O uso de CONCURRENTLY requer índices únicos nas MVs (já criados acima).
-- Alternativamente, use REFRESH MATERIALIZED VIEW (sem CONCURRENTLY) quando locks não forem um problema.

-- FIM DO SCRIPT N2.A1
