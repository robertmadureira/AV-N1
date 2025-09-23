TRUNCATE TABLE
    "user",
    roles,
    modules,
    "group",
    features_modules,
    features,
    "permission",
    user_roles,
    user_group
RESTART IDENTITY CASCADE;

SELECT 'Todas as tabelas foram limpas e os contadores de ID reiniciados com sucesso.';
