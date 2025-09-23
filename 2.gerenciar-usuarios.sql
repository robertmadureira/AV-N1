-- consulta principal
SELECT
    u.primary_name,
    u.last_name,
    u.email,
    ARRAY_AGG(DISTINCT r.name) AS roles, 
    ARRAY_AGG(DISTINCT g.name) AS groups,   
    u.last_access
FROM
    "user" u
LEFT JOIN
    user_group ug ON ug.user_id = u.id
LEFT JOIN
    "group" g ON g.id = ug.group_id
LEFT JOIN
    user_roles ur ON ur.user_id = u.id
LEFT JOIN
    roles r ON r.id = ur.roles_id
where
	u.is_deleted = false 
	and g.is_active and not g.is_deleted
	and r.is_active and not g.is_deleted
	and ug.is_active and not ug.is_deleted 
	and ur.is_active and not ur.is_deleted
GROUP BY
    u.id;


--insert usuario
BEGIN;
DO $$
DECLARE
    new_user_id INT;
BEGIN
    INSERT INTO "user" (email)
    VALUES ('novo.usuario@example.com')
    RETURNING id INTO new_user_id;

    INSERT INTO user_roles (user_id, roles_id)
    VALUES (new_user_id, (SELECT id FROM roles WHERE name = 'Viewer'));

    INSERT INTO user_group (user_id, group_id)
    VALUES (new_user_id, (SELECT id FROM "group" WHERE name = 'External Auditors'));

END $$;
COMMIT;


-- atualizar de usuario
UPDATE "user"
SET
    primary_name = 'Brunno',
    last_name = 'Costela',
    modification_date = CURRENT_TIMESTAMP
WHERE
    email = 'bruno.costa@example.com';
    
-- excluir usuario
update "user"
set is_active = false, is_deleted = true 
where email = bruno.costa@example.com
