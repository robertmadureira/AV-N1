-- group_permissions_examples.sql
-- PostgreSQL – Gerenciamento de Grupos e Permissões
-- Inclui exemplos de consultas, cadastros, edições e exclusões de grupos,
-- além da vinculação de usuários e permissões (features).

/* ===============================================================
   EXEMPLOS DE CADASTRO (INSERT)
   =============================================================== */
-- 1) Criar novo grupo "Cadastro de contratos"
INSERT INTO "group" (name)
VALUES ('Cadastro de contratos')
ON CONFLICT (name) DO NOTHING;

-- 2) Criar grupo "Validação de CNPJ"
INSERT INTO "group" (name)
VALUES ('Validação de CNPJ')
ON CONFLICT (name) DO NOTHING;


/* ===============================================================
   EXEMPLOS DE EDIÇÃO (UPDATE)
   =============================================================== */
-- 1) Alterar o nome de um grupo existente
UPDATE "group"
SET name = 'Gestão de Contratos'
WHERE name = 'Cadastro de contratos';

-- 2) Desativar um grupo (sem excluir fisicamente)
UPDATE "group"
SET is_active = FALSE, modification_date = NOW()
WHERE name = 'Validação de CNPJ';


/* ===============================================================
   EXEMPLOS DE EXCLUSÃO (DELETE / exclusão lógica)
   =============================================================== */
-- 1) Exclusão lógica de grupo
UPDATE "group"
SET is_deleted = TRUE, modification_date = NOW()
WHERE name = 'Gestão de Contratos';

-- 2) Exclusão lógica de grupo
UPDATE "group"
SET is_deleted = TRUE, modification_date = NOW()
WHERE name = 'Validação de CNPJ';


/* ===============================================================
   EXEMPLOS DE CONSULTA (SELECT)
   =============================================================== */
-- 1) Listar grupos com quantidade de permissões e usuários vinculados
SELECT g.name AS grupo,
       COUNT(DISTINCT p.id) AS permissoes,
       COUNT(DISTINCT ug.user_id) AS usuarios
FROM "group" g
LEFT JOIN "permission" p ON g.id = p.group_id
LEFT JOIN user_group ug ON g.id = ug.group_id
WHERE g.is_deleted = FALSE
GROUP BY g.name
ORDER BY g.name;

-- 2) Consultar permissões (features) associadas a um grupo específico
SELECT g.name AS grupo,
       f.feature_key AS funcionalidade,
       p.is_active AS permissao_ativa
FROM "group" g
JOIN "permission" p ON g.id = p.group_id
JOIN features f ON f.id = p.features_id
WHERE g.name = 'Sales Team';


/* ===============================================================
   EXEMPLOS DE VINCULAÇÃO DE USUÁRIOS E PERMISSÕES
   =============================================================== */
-- 1) Vincular usuário a um grupo
INSERT INTO user_group (user_id, group_id)
VALUES (
    (SELECT id FROM "user" WHERE email = 'ana.silva@example.com'),
    (SELECT id FROM "group" WHERE name = 'Sales Team')
)
ON CONFLICT DO NOTHING;

-- 2) Dar permissão de "EXPORT_SALES_PDF" ao grupo "Sales Team"
INSERT INTO "permission" (features_id, group_id)
VALUES (
    (SELECT id FROM features WHERE feature_key = 'EXPORT_SALES_PDF'),
    (SELECT id FROM "group" WHERE name = 'Sales Team')
)
ON CONFLICT DO NOTHING;
