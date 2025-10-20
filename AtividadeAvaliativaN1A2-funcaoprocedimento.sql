--Atividade Avaliativa N1.A2: função e procedimento
-- Alunos: Pedro Peixoto e Robert Madureira

-------------------------------

-- 1.Criar a FUNÇÃO fu_validar_cadastro cuja ENTRADA é o e-mail de um usuário e a SAÍDA é TRUE (e-mail cadastrado na base de dados) ou FALSE (e-mail não cadastrado). 

CREATE OR REPLACE FUNCTION fu_validar_cadastro(
    p_email TEXT  -- p_email: Parâmetro de entrada com o e-mail a ser verificado
)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (SELECT 1 FROM "user" WHERE email = p_email);
END;
$$ LANGUAGE plpgsql;

-- 2. Criar a FUNÇÃO fu_validar_email cuja ENTRADA é o e-mail digitado pelo usuário e a SAÍDA é TRUE (e-mail válido segundo regras de validação de e-mail) ou FALSE (e-mail inválido). 

CREATE OR REPLACE FUNCTION fu_validar_email(
    p_email TEXT 
)
RETURNS BOOLEAN AS $$
BEGIN
    IF p_email IS NULL OR p_email = '' THEN
        RETURN FALSE;
    END IF;

    RETURN p_email ~ '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';

END;
$$ LANGUAGE plpgsql;

-- 3. Criar a FUNÇÃO fu_formatar_tempo_acesso cuja ENTRADA é a data-hora do último acesso do usuário a SAÍDA é o tempo decorrido da data-hora atual em relação a data-hora do último acesso. Exemplo de saída: 3 segundos, 10 minutos, 5 horas, 15 dias, 3 meses, 3 anos e nunca acessou.

CREATE OR REPLACE FUNCTION fu_formatar_tempo_acesso(
    p_last_access TIMESTAMP WITH TIME ZONE 
)
RETURNS TEXT AS $$
DECLARE
    intervalo_tempo INTERVAL;
    total_segundos NUMERIC;

    anos INT;
    meses INT;
    dias INT;
    horas INT;
    minutos INT;
    segundos INT;
BEGIN
    IF p_last_access IS NULL THEN
        RETURN 'Nunca acessou';
    END IF;

    intervalo_tempo := NOW() - p_last_access;

    total_segundos := EXTRACT(EPOCH FROM intervalo_tempo);

	-- Anos (1 ano = 365 dias)
    IF total_segundos >= 31536000 THEN
        anos := FLOOR(total_segundos / 31536000);
        IF anos = 1 THEN
            RETURN '1 ano';
        ELSE
            RETURN anos || ' anos';
        END IF;

    -- Meses (1 mês = 30 dias)
    ELSIF total_segundos >= 2592000 THEN
        meses := FLOOR(total_segundos / 2592000);
        IF meses = 1 THEN
            RETURN '1 mês';
        ELSE
            RETURN meses || ' meses';
        END IF;

    -- Dias (1 dia = 24 horas)
    ELSIF total_segundos >= 86400 THEN
        dias := FLOOR(total_segundos / 86400);
        IF dias = 1 THEN
            RETURN '1 dia';
        ELSE
            RETURN dias || ' dias';
        END IF;

    -- Horas (1 hora = 60 minutos)
    ELSIF total_segundos >= 3600 THEN
        horas := FLOOR(total_segundos / 3600);
        IF horas = 1 THEN
            RETURN '1 hora';
        ELSE
            RETURN horas || ' horas';
        END IF;

    -- Minutos (1 minuto = 60 segundos)
    ELSIF total_segundos >= 60 THEN
        minutos := FLOOR(total_segundos / 60);
        IF minutos = 1 THEN
            RETURN '1 minuto';
        ELSE
            RETURN minutos || ' minutos';
        END IF;
    
    -- Segundos (para intervalos menores que 1 minuto)
    ELSE
        segundos := FLOOR(total_segundos);
        IF segundos <= 1 THEN
            RETURN '1 segundo';
        ELSE
            RETURN segundos || ' segundos';
        END IF;
    END IF;

END;
$$ LANGUAGE plpgsql;

-- 4. Criar o PROCEDIMENTO pr_excluir_usuario cuja ENTRADA é o identificador de um usuário e a  SAÍDA é TRUE (exclusão realizada com sucesso) ou FALSE (não foi possível realizar a exclusão). Usuários cujo grupo seja “Administrador” não podem ser excluídos. Esta exclusão não pode ser feita em cascata (propriedade estabelecida na criação da tabela) e deve respeitar as restrições de integridade da modelagem (chave primária e chave estrangeira).

CREATE OR REPLACE PROCEDURE pr_excluir_usuario(
    p_user_id INT,             
    INOUT p_success BOOLEAN     
)
LANGUAGE plpgsql
AS $$
DECLARE
    is_admin BOOLEAN;
BEGIN
    p_success := FALSE;

    IF NOT EXISTS (SELECT 1 FROM "user" WHERE id = p_user_id) THEN
        RAISE NOTICE 'FALHA: Usuário com ID % não encontrado.', p_user_id;
        RETURN; 
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM user_group ug
        JOIN "group" g ON ug.group_id = g.id
        WHERE ug.user_id = p_user_id AND g.name IN = ('Administrador','Global Administrators');
    ) INTO is_admin;

    IF is_admin THEN
        RAISE NOTICE 'FALHA: Não é permitido excluir usuários do grupo "Global Administrators". Usuário ID: %', p_user_id;
        RETURN; 
    END IF;

    RAISE NOTICE 'Removendo relacionamentos do usuário ID %...', p_user_id;
    DELETE FROM user_roles WHERE user_id = p_user_id;
    DELETE FROM user_group WHERE user_id = p_user_id;

    RAISE NOTICE 'Removendo registro principal do usuário ID %...', p_user_id;
    DELETE FROM "user" WHERE id = p_user_id;

    RAISE NOTICE 'SUCESSO: Usuário com ID % foi excluído.', p_user_id;
    p_success := TRUE;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERRO INESPERADO: Ocorreu um erro ao excluir o usuário ID %. A transação foi desfeita.', p_user_id;
        p_success := FALSE;
END;
$$;

-- 5. Criar a FUNÇÃO fu_migrar_usuarios_grupo cuja entrada seja o nome de um Grupo de Origem e o nome de um Grupo de Destino e a SAÍDA seja uma lista (nome, e-mail, último acesso) dos usuários do Grupo de Origem. O processamento deve migrar todos os usuários vinculados ao grupo de Origem para o Grupo de Destino.

CREATE OR REPLACE FUNCTION fu_migrar_usuarios_grupo(
    p_grupo_origem_nome TEXT,  
    p_grupo_destino_nome TEXT   
)
RETURNS TABLE(
    nome_completo TEXT,
    email_usuario TEXT,
    ultimo_acesso TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_origem_id INT;
    v_destino_id INT;
BEGIN
    SELECT id INTO v_origem_id FROM "group" WHERE name = p_grupo_origem_nome;
    SELECT id INTO v_destino_id FROM "group" WHERE name = p_grupo_destino_nome;

    IF v_origem_id IS NULL THEN
        RAISE EXCEPTION 'Grupo de origem "%" não encontrado.', p_grupo_origem_nome;
    END IF;

    IF v_destino_id IS NULL THEN
        RAISE EXCEPTION 'Grupo de destino "%" não encontrado.', p_grupo_destino_nome;
    END IF;

    IF v_origem_id = v_destino_id THEN
        RAISE EXCEPTION 'O grupo de origem e destino não podem ser o mesmo.';
    END IF;

    RETURN QUERY
    WITH usuarios_removidos AS (
        DELETE FROM user_group
        WHERE group_id = v_origem_id
        RETURNING user_id
    ),
    usuarios_adicionados AS (
        INSERT INTO user_group (user_id, group_id)
        SELECT user_id, v_destino_id FROM usuarios_removidos
        ON CONFLICT (user_id, group_id) DO NOTHING
    )
    SELECT
        u.primary_name || ' ' || u.last_name,
        u.email,
        u.last_access
    FROM "user" u
    WHERE u.id IN (SELECT user_id FROM usuarios_removidos);

END;
$$;

-- 6. Criar o PROCEDIMENTO pr_copiar_grupo cuja entrada seja o nome de um Grupo  já existente e o nome de um novo grupo que será criado pelo procedimento e a SAÍDA seja a quantidade de funcionalidades com permissões habilitadas no grupo. O processamento deve criar uma cópia na íntegra do grupo e seus relacionamentos com o nome recebido por parâmetro.

CREATE OR REPLACE PROCEDURE pr_copiar_grupo(
    p_grupo_origem_nome TEXT,  
    p_novo_grupo_nome TEXT,     
    INOUT p_permissoes_copiadas INT 
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_origem_id INT;
    v_novo_grupo_id INT;
BEGIN
    p_permissoes_copiadas := 0;

    IF p_grupo_origem_nome = p_novo_grupo_nome THEN
        RAISE EXCEPTION 'O nome do grupo de origem e de destino não podem ser iguais.';
    END IF;

    SELECT id INTO v_origem_id FROM "group" WHERE name = p_grupo_origem_nome;
    IF v_origem_id IS NULL THEN
        RAISE EXCEPTION 'O grupo de origem "%" não foi encontrado.', p_grupo_origem_nome;
    END IF;

    IF EXISTS (SELECT 1 FROM "group" WHERE name = p_novo_grupo_nome) THEN
        RAISE EXCEPTION 'O nome para o novo grupo "%" já está em uso.', p_novo_grupo_nome;
    END IF;

    RAISE NOTICE 'Criando novo grupo "%"...', p_novo_grupo_nome;
    INSERT INTO "group" (name) VALUES (p_novo_grupo_nome) RETURNING id INTO v_novo_grupo_id;

    RAISE NOTICE 'Copiando permissões do grupo "%" para "%"...', p_grupo_origem_nome, p_novo_grupo_nome;
    INSERT INTO "permission" (group_id, features_id)
    SELECT
        v_novo_grupo_id, 
        p.features_id    
    FROM "permission" p
    WHERE p.group_id = v_origem_id;

    GET DIAGNOSTICS p_permissoes_copiadas = ROW_COUNT;

    RAISE NOTICE 'SUCESSO: Grupo "%" criado com % permissões copiadas.', p_novo_grupo_nome, p_permissoes_copiadas;

END;
$$;

-- 7. Criar a FUNÇÃO fu_verificar_engajamento cuja SAÍDA seja a lista de usuários cadastrados classificados por grau de engajamento com a plataforma, onde: Alto-usuário acessou a plataforma nos últimos 2 dias. Médio-usuário acessou a plataforma nos últimos 7 dias. Baixo-usuário acessou a plataforma nos últimos 30 dias e Inexistente-usuário nunca acessou a plataforma.

CREATE OR REPLACE FUNCTION fu_verificar_engajamento()
RETURNS TABLE(
    id_usuario INT,
    nome_completo TEXT,
    email TEXT,
    ultimo_acesso TIMESTAMP WITH TIME ZONE,
    nivel_engajamento TEXT
)
LANGUAGE sql
AS $$
SELECT
    u.id,
    u.primary_name || ' ' || u.last_name,
    u.email,
    u.last_access,
    CASE
        WHEN u.last_access IS NULL THEN 'Inexistente'
        WHEN u.last_access >= (NOW() - INTERVAL '2 days') THEN 'Alto'
        WHEN u.last_access >= (NOW() - INTERVAL '7 days') THEN 'Médio'
        WHEN u.last_access >= (NOW() - INTERVAL '30 days') THEN 'Baixo'
        ELSE 'Baixo' 
    END AS nivel_engajamento
FROM
    "user" u
ORDER BY
    CASE
        WHEN u.last_access IS NULL THEN 5 -- Inexistente fica por último
        WHEN u.last_access >= (NOW() - INTERVAL '2 days') THEN 1 -- Alto
        WHEN u.last_access >= (NOW() - INTERVAL '7 days') THEN 2 -- Médio
        WHEN u.last_access >= (NOW() - INTERVAL '30 days') THEN 3 -- Baixo
        ELSE 4 -- Antigo
    END,
    u.last_access DESC NULLS LAST; -- Como critério de desempate, o acesso mais recente primeiro.

$$;

-- 8. Criar o PROCEDIMENTO pr_criar_usuario_adm cuja ENTRADA é o e-mail admin@ufg.br e nome do grupo “Administrador”. O processamento dever criar o usuário, criar o grupo, habilitar todas as funcionalidades para o grupo e vincular o usuário ao grupo. Deve ser utilizada a função pr_validar_cadastro para não duplicar o usuário

CREATE OR REPLACE PROCEDURE pr_criar_usuario_adm(
    p_email TEXT DEFAULT 'admin@ufg.br',
    p_nome_grupo TEXT DEFAULT 'Administrador'
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id INT;
    v_group_id INT;
    v_permissoes_concedidas INT;
BEGIN
    IF fu_validar_cadastro(p_email) THEN
        RAISE NOTICE 'Usuário "%" já existe. Obtendo seu ID.', p_email;
        SELECT id INTO v_user_id FROM "user" WHERE email = p_email;
    ELSE
        RAISE NOTICE 'Usuário "%" não encontrado. Criando novo usuário...', p_email;
        INSERT INTO "user" (email) VALUES (p_email) RETURNING id INTO v_user_id;
    END IF;

    SELECT id INTO v_group_id FROM "group" WHERE name = p_nome_grupo;
    IF v_group_id IS NOT NULL THEN
        RAISE NOTICE 'Grupo "%" já existe. Obtendo seu ID.', p_nome_grupo;
    ELSE
        RAISE NOTICE 'Grupo "%" não encontrado. Criando novo grupo...', p_nome_grupo;
        INSERT INTO "group" (name) VALUES (p_nome_grupo) RETURNING id INTO v_group_id;
    END IF;

    RAISE NOTICE 'Concedendo todas as permissões ao grupo "%"...', p_nome_grupo;
    INSERT INTO "permission" (group_id, features_id)
    SELECT v_group_id, f.id FROM features f
    ON CONFLICT (group_id, features_id) DO NOTHING;

    GET DIAGNOSTICS v_permissoes_concedidas = ROW_COUNT;
    RAISE NOTICE '% novas permissões foram concedidas.', v_permissoes_concedidas;

    RAISE NOTICE 'Vinculando usuário "%" ao grupo "%"...', p_email, p_nome_grupo;
    INSERT INTO user_group (user_id, group_id)
    VALUES (v_user_id, v_group_id)
    ON CONFLICT (user_id, group_id) DO NOTHING;

    RAISE NOTICE 'Procedimento concluído com sucesso!';

END;

$$;
