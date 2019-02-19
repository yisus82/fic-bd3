CREATE TABLE usuario (
	prioridad NUMBER,
	loginUsuario VARCHAR(10),
	CONSTRAINT pk_usuario PRIMARY KEY(loginUsuario)
);

CREATE TABLE programa (
	loginUsuario VARCHAR(10),
	nombrePrograma VARCHAR(20),
	coste NUMBER,
	CONSTRAINT pk_programa PRIMARY KEY(loginUsuario, nombrePrograma),
	CONSTRAINT fk_programa_login FOREIGN KEY(loginUsuario) REFERENCES usuario(loginUsuario)
);

CREATE TABLE servidor (
	nombreServidor VARCHAR(10),
	capacidad NUMBER,
	restrictivo CHAR(1),
	CONSTRAINT pk_servidor PRIMARY KEY(nombreServidor),
	CONSTRAINT chk_restrictivo CHECK((restrictivo = 't') OR (restrictivo = 'f'))
);

CREATE TABLE conexion (
	identificador NUMBER,
	loginUsuario VARCHAR(10),
	nombrePrograma VARCHAR(20),
	nombreServidor VARCHAR(10),
	CONSTRAINT pk_conexion PRIMARY KEY(identificador),
	CONSTRAINT fk_conexion_login_programa FOREIGN KEY(loginUsuario, nombrePrograma)
		REFERENCES programa(loginUsuario, nombrePrograma),
	CONSTRAINT fk_conexion_servidor FOREIGN KEY(nombreServidor)
		REFERENCES servidor(nombreServidor)
);