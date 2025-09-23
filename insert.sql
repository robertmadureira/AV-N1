do $$ begin
	INSERT INTO "user" (primary_name, last_name, email, last_access) VALUES
	('Ana', 'Silva', 'ana.silva@example.com', NOW() - INTERVAL '1 day'),
	('Bruno', 'Costa', 'bruno.costa@example.com', NOW() - INTERVAL '2 hours'),
	('Carlos', 'Pereira', 'carlos.pereira@example.com', NOW() - INTERVAL '5 days'),
	('Daniela', 'Almeida', 'daniela.almeida@example.com', NOW()),
	('Eduardo', 'Rocha', 'eduardo.rocha@example.com', NOW() - INTERVAL '10 minutes'),
	('Fernanda', 'Lima', 'fernanda.lima@example.com', NULL),
	('Gustavo', 'Martins', 'gustavo.martins@example.com', NOW() - INTERVAL '3 weeks'),
	('Helena', 'Souza', 'helena.souza@example.com', NOW() - INTERVAL '4 hours'),
	('Igor', 'Fernandes', 'igor.fernandes@example.com', NULL),
	('Juliana', 'Ribeiro', 'juliana.ribeiro@example.com', NOW() - INTERVAL '1 month')
	ON CONFLICT (email) DO NOTHING; -- Evita erro se o email já existir
	
	--------------------------------------------------------------------------------
	
	INSERT INTO roles (name) VALUES
	('Super Admin'),
	('Administrator'),
	('Content Editor'),
	('Sales Manager'),
	('Viewer')
	ON CONFLICT (name) DO NOTHING;
	
	--------------------------------------------------------------------------------
	
	INSERT INTO modules (module_key) VALUES
	('DASHBOARD'),
	('USER_MANAGEMENT'),
	('REPORTS'),
	('SETTINGS'),
	('INVENTORY_CONTROL')
	ON CONFLICT (module_key) DO NOTHING;
	
	--------------------------------------------------------------------------------
	
	INSERT INTO "group" (name) VALUES
	('Global Administrators'),
	('Content Managers'),
	('Sales Team'),
	('Support Team'),
	('External Auditors')
	ON CONFLICT (name) DO NOTHING; 
	
	--------------------------------------------------------------------------------
	
	INSERT INTO features_modules (name, module_id) VALUES
	('User Administration', (SELECT id FROM modules WHERE module_key = 'USER_MANAGEMENT')),
	('System Configuration', (SELECT id FROM modules WHERE module_key = 'SETTINGS')),
	('Sales Analytics', (SELECT id FROM modules WHERE module_key = 'REPORTS')),
	('Product Management', (SELECT id FROM modules WHERE module_key = 'INVENTORY_CONTROL')),
	('Profile Settings', (SELECT id FROM modules WHERE module_key = 'USER_MANAGEMENT')),
	('Dashboard Widgets', (SELECT id FROM modules WHERE module_key = 'DASHBOARD')),
	('Financial Reports', (SELECT id FROM modules WHERE module_key = 'REPORTS'))
	ON CONFLICT (name) DO NOTHING;
	
	--------------------------------------------------------------------------------
	
	INSERT INTO features (feature_key, features_modules_id) VALUES
	('CREATE_USER', (SELECT id FROM features_modules WHERE name = 'User Administration')),
	('EDIT_USER', (SELECT id FROM features_modules WHERE name = 'User Administration')),
	('DELETE_USER', (SELECT id FROM features_modules WHERE name = 'User Administration')),
	('VIEW_USER_LIST', (SELECT id FROM features_modules WHERE name = 'User Administration')),
	('CHANGE_SYSTEM_LOGO', (SELECT id FROM features_modules WHERE name = 'System Configuration')),
	('SET_API_KEYS', (SELECT id FROM features_modules WHERE name = 'System Configuration')),
	('VIEW_SALES_REPORTS', (SELECT id FROM features_modules WHERE name = 'Sales Analytics')),
	('EXPORT_SALES_PDF', (SELECT id FROM features_modules WHERE name = 'Sales Analytics')),
	('CREATE_PRODUCT', (SELECT id FROM features_modules WHERE name = 'Product Management')),
	('EDIT_PRODUCT_STOCK', (SELECT id FROM features_modules WHERE name = 'Product Management')),
	('CHANGE_OWN_PASSWORD', (SELECT id FROM features_modules WHERE name = 'Profile Settings'))
	ON CONFLICT (feature_key) DO NOTHING;
	
	--------------------------------------------------------------------------------
	
	INSERT INTO "permission" (features_id, group_id) VALUES
	((SELECT id FROM features WHERE feature_key = 'CREATE_USER'), (SELECT id FROM "group" WHERE name = 'Global Administrators')),
	((SELECT id FROM features WHERE feature_key = 'EDIT_USER'), (SELECT id FROM "group" WHERE name = 'Global Administrators')),
	((SELECT id FROM features WHERE feature_key = 'DELETE_USER'), (SELECT id FROM "group" WHERE name = 'Global Administrators')),
	((SELECT id FROM features WHERE feature_key = 'CREATE_PRODUCT'), (SELECT id FROM "group" WHERE name = 'Content Managers')),
	((SELECT id FROM features WHERE feature_key = 'VIEW_SALES_REPORTS'), (SELECT id FROM "group" WHERE name = 'Sales Team')),
	((SELECT id FROM features WHERE feature_key = 'EXPORT_SALES_PDF'), (SELECT id FROM "group" WHERE name = 'Sales Team')),
	((SELECT id FROM features WHERE feature_key = 'VIEW_USER_LIST'), (SELECT id FROM "group" WHERE name = 'Support Team')),
	((SELECT id FROM features WHERE feature_key = 'VIEW_SALES_REPORTS'), (SELECT id FROM "group" WHERE name = 'External Auditors'));
	
	--------------------------------------------------------------------------------
	
	INSERT INTO user_roles (user_id, roles_id) VALUES
	((SELECT id FROM "user" WHERE email = 'ana.silva@example.com'), (SELECT id FROM roles WHERE name = 'Super Admin')),
	((SELECT id FROM "user" WHERE email = 'bruno.costa@example.com'), (SELECT id FROM roles WHERE name = 'Administrator')),
	((SELECT id FROM "user" WHERE email = 'carlos.pereira@example.com'), (SELECT id FROM roles WHERE name = 'Sales Manager')),
	((SELECT id FROM "user" WHERE email = 'daniela.almeida@example.com'), (SELECT id FROM roles WHERE name = 'Content Editor')),
	((SELECT id FROM "user" WHERE email = 'eduardo.rocha@example.com'), (SELECT id FROM roles WHERE name = 'Viewer')),
	((SELECT id FROM "user" WHERE email = 'fernanda.lima@example.com'), (SELECT id FROM roles WHERE name = 'Content Editor')),
	((SELECT id FROM "user" WHERE email = 'helena.souza@example.com'), (SELECT id FROM roles WHERE name = 'Administrator'));
	
	--------------------------------------------------------------------------------
	
	INSERT INTO user_group (user_id, group_id) VALUES
	((SELECT id FROM "user" WHERE email = 'ana.silva@example.com'), (SELECT id FROM "group" WHERE name = 'Global Administrators')),
	((SELECT id FROM "user" WHERE email = 'bruno.costa@example.com'), (SELECT id FROM "group" WHERE name = 'Global Administrators')),
	((SELECT id FROM "user" WHERE email = 'carlos.pereira@example.com'), (SELECT id FROM "group" WHERE name = 'Sales Team')),
	((SELECT id FROM "user" WHERE email = 'daniela.almeida@example.com'), (SELECT id FROM "group" WHERE name = 'Content Managers')),
	((SELECT id FROM "user" WHERE email = 'fernanda.lima@example.com'), (SELECT id FROM "group" WHERE name = 'Content Managers')),
	((SELECT id FROM "user" WHERE email = 'helena.souza@example.com'), (SELECT id FROM "group" WHERE name = 'Support Team')),
	((SELECT id FROM "user" WHERE email = 'juliana.ribeiro@example.com'), (SELECT id FROM "group" WHERE name = 'External Auditors'));
end $$;