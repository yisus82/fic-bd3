CREATE OR REPLACE FUNCTION recursosLibres(nombreServ IN servidor.nombreServidor%TYPE)
RETURN servidor.capacidad%TYPE
IS
	cap servidor.capacidad%TYPE := 0;
	ocupado servidor.capacidad%TYPE := 0;
BEGIN
	SELECT capacidad INTO cap
	FROM servidor
	WHERE nombreServidor = nombreServ;

	SELECT NVL(SUM(coste), 0) INTO ocupado
	FROM programa NATURAL JOIN conexion
	WHERE nombreServidor = nombreServ;

	RETURN cap - ocupado;
END;


/*
	Funcion para buscar servidores libres.
*/

CREATE OR REPLACE FUNCTION buscaServidor(loginUsu IN usuario.loginUsuario%TYPE,
					nombreProg IN programa.nombrePrograma%TYPE)
RETURN servidor.nombreServidor%TYPE
IS
	costeProg programa.coste%TYPE := 0;

	CURSOR c_servidores_no_restrictivos IS
		SELECT nombreServidor
		FROM servidor
		WHERE restrictivo = 'f'
		AND recursosLibres(nombreServidor) >= costeProg;

	CURSOR c_servidores_restrictivos IS
		SELECT nombreServidor
		FROM servidor
		WHERE restrictivo = 't'
		AND recursosLibres(nombreServidor) >= costeProg;

	nombreServ servidor.nombreServidor%TYPE;
	cont NUMBER := 0;
BEGIN
	SELECT coste INTO costeProg
	FROM programa
	WHERE nombrePrograma = nombreProg;

	OPEN c_servidores_no_restrictivos;

	LOOP
		FETCH c_servidores_no_restrictivos INTO nombreServ;
		EXIT WHEN c_servidores_no_restrictivos%NOTFOUND;

		RETURN nombreServ;
	END LOOP;

	OPEN c_servidores_restrictivos;

	LOOP
		FETCH c_servidores_restrictivos INTO nombreServ;
		EXIT WHEN c_servidores_restrictivos%NOTFOUND;

		SELECT COUNT(*) INTO cont
		FROM conexion
		WHERE nombreServidor = nombreServ
		AND loginUsuario = loginUsu;

		IF cont = 0 THEN
			RETURN nombreServ;
		END IF;
	END LOOP;

	RAISE_APPLICATION_ERROR(-20001, 'No hay servidores disponibles');
END;

/*
	En un servidor no se pueden estar ejecutando programas cuya suma en coste
	supere la capacidad del servidor.
*/
CREATE OR REPLACE TRIGGER control_capacidad
BEFORE INSERT ON conexion
FOR EACH ROW
DECLARE
	costeProg programa.coste%TYPE;
BEGIN
	SELECT coste INTO costeProg
	FROM programa
	WHERE nombrePrograma = :NEW.nombrePrograma;

	IF recursosLibres(:NEW.nombreServidor) < costeProg THEN
		:NEW.nombreServidor := buscaServidor(:NEW.loginUsuario, :NEW.nombrePrograma);
	END IF;
END;


/*
	Las prioridades se tratan individualmente para cada servidor: un usuario
	con menos prioridad que otro no puede tener ejecutando en su servidor un
	programa con un coste mayor que el programa que tenga ejecutando el segundo
	usuario.
*/

CREATE OR REPLACE TRIGGER control_prioridad
BEFORE INSERT ON conexion
FOR EACH ROW
DECLARE
	cont NUMBER := 0;
BEGIN
	SELECT COUNT(*) INTO cont
	FROM conexion NATURAL JOIN usuario NATURAL JOIN programa
	WHERE nombreServidor = :NEW.nombreServidor
	AND prioridad < (SELECT prioridad FROM usuario WHERE loginUsuario = :NEW.loginUsuario)
	AND coste < (SELECT coste FROM programa WHERE loginUsuario = :NEW.loginUsuario
						AND nombrePrograma = :NEW.nombrePrograma);

	IF cont > 0 THEN
		:NEW.nombreServidor := buscaServidor(:NEW.loginUsuario, :NEW.nombrePrograma);
	END IF;
END;

/*
	Cuando un programa tiene coste 0 (es decir, ya ha terminado de ejecutarse),
	ha de borrarse de la relacion 'programa' y, por ende, de la relacion
	'conexion'.
*/

CREATE OR REPLACE TRIGGER control_coste
AFTER INSERT OR UPDATE OF coste ON programa
DECLARE
	CURSOR c_programa IS
		SELECT nombrePrograma
		FROM programa
		WHERE coste = 0;
	nombreP programa.nombrePrograma%TYPE;
BEGIN
	OPEN c_programa;

	LOOP
		FETCH c_programa INTO nombreP;
		EXIT WHEN c_programa%NOTFOUND;

		DELETE FROM conexion
		WHERE nombrePrograma = nombreP;
	END LOOP;

	DELETE FROM programa
	WHERE coste = 0;
END;

/*
	En los servidores restrictivos, los usuarios solo pueden tener corriendo
	un programa propio al mismo tiempo. Es decir, no es posible que un mismo
	usuario tenga dos o mas programas conectados a un servidor restrictivo.
*/

CREATE OR REPLACE TRIGGER control_restrictivo
BEFORE INSERT ON conexion
FOR EACH ROW
DECLARE
	cont NUMBER := 0;
BEGIN
	SELECT COUNT(*) INTO cont
	FROM usuario NATURAL JOIN conexion NATURAL JOIN servidor
	WHERE restrictivo = 't'
	AND loginUsuario = :NEW.loginUsuario
	AND nombreServidor = :NEW.nombreServidor;

	IF cont > 0 THEN
		:NEW.nombreServidor := buscaServidor(:NEW.loginUsuario, :NEW.nombrePrograma);
	END IF;
END;











