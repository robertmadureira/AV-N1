do $$ begin
	CREATE TABLE "user" (
	    id SERIAL PRIMARY KEY,
	    primary_name VARCHAR(100),
	    last_name VARCHAR(100),
	    email VARCHAR(255) NOT NULL UNIQUE,
	    last_access TIMESTAMP WITH TIME ZONE,
	    is_active BOOLEAN NOT NULL DEFAULT TRUE,
	    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
	    creation_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
	    modification_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
	);
	
	CREATE TABLE roles (
	    id SERIAL PRIMARY KEY,
	    name VARCHAR(100) NOT NULL UNIQUE,
	    is_active BOOLEAN NOT NULL DEFAULT TRUE,
	    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
	    creation_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
	    modification_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
	);
	
	CREATE TABLE modules (
	    id SERIAL PRIMARY KEY,
	    module_key VARCHAR(50) NOT NULL UNIQUE,
	    is_active BOOLEAN NOT NULL DEFAULT TRUE,
	    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
	    creation_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
	    modification_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
	);
	
	CREATE TABLE features_modules (
	    id SERIAL PRIMARY KEY,
	    name VARCHAR(50) NOT NULL UNIQUE,
	    module_id INT NOT NULL,
	    is_active BOOLEAN NOT NULL DEFAULT TRUE,
	    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
	    creation_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
	    modification_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
	    
	    CONSTRAINT fk_module
	        FOREIGN KEY(module_id) 
	        REFERENCES modules(id)
	);
	
	CREATE TABLE features (
	    id SERIAL PRIMARY KEY,
	    feature_key VARCHAR(100) NOT NULL UNIQUE,
	    features_modules_id INT NOT NULL,
	    is_active BOOLEAN NOT NULL DEFAULT TRUE,
	    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
	    creation_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
	    modification_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
	    
	    CONSTRAINT fk_features_modules
	        FOREIGN KEY(features_modules_id) 
	        REFERENCES features_modules(id)
	);
	
	create table "group" (
		id SERIAL PRIMARY KEY,
	    name VARCHAR(100) NOT NULL UNIQUE,
	    is_active BOOLEAN NOT NULL DEFAULT TRUE,
	    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
	    creation_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
	    modification_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
	);
	
	create table "permission" (
		id SERIAL PRIMARY KEY,
	    features_id INT NOT NULL,
	    group_id INT NOT NULL,
	    is_active BOOLEAN NOT NULL DEFAULT TRUE,
	    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
	    creation_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
	    modification_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
	    
	    CONSTRAINT fk_group
	        FOREIGN KEY(group_id) 
	        REFERENCES "group"(id),
	        
	    CONSTRAINT fk_features
	        FOREIGN KEY(features_id) 
	        REFERENCES features(id)    
	);
	
	create table user_roles (
		id SERIAL PRIMARY KEY,
	    user_id INT NOT NULL,
	    roles_id INT NOT NULL,
	    is_active BOOLEAN NOT NULL DEFAULT TRUE,
	    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
	    creation_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
	    modification_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
	    
	    CONSTRAINT fk_users
	        FOREIGN KEY(user_id) 
	        REFERENCES "user"(id),
	        
	    CONSTRAINT fk_roles
	        FOREIGN KEY(roles_id) 
	        REFERENCES roles(id)   
	);
	
	create table user_group (
		id SERIAL PRIMARY KEY,
	    user_id INT NOT NULL,
	    group_id INT NOT NULL,
	    is_active BOOLEAN NOT NULL DEFAULT TRUE,
	    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
	    creation_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
	    modification_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
	    
	    CONSTRAINT fk_users
	        FOREIGN KEY(user_id) 
	        REFERENCES "user"(id),
	        
	    CONSTRAINT fk_group
	        FOREIGN KEY(group_id) 
	        REFERENCES "group"(id)   
	);
end $$;
