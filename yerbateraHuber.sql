CREATE SCHEMA yerbateraHuber;

USE yerbateraHuber;

CREATE TABLE lotes (
id_lote INT AUTO_INCREMENT,
nombre_lote VARCHAR(30),
hectareas DECIMAL(10,2),
ubicacion VARCHAR(50),
fecha_plantacion DATE,
PRIMARY KEY (id_lote));

CREATE TABLE personal(
id_personal INT AUTO_INCREMENT,
nombre_completo VARCHAR(50),
rol VARCHAR(50),
fecha_inicio DATE,
estado VARCHAR(20),
PRIMARY KEY (id_personal));

CREATE TABLE cosechas (
id_cosechas INT AUTO_INCREMENT,
id_lote INT,
id_personal INT,
fecha_cosecha DATE,
kilos_cosechados INT,
PRIMARY KEY (id_cosechas),
FOREIGN KEY (id_lote) REFERENCES lotes(id_lote),
FOREIGN KEY (id_personal) REFERENCES personal(id_personal));

USE yerbateraHuber;

CREATE TABLE entregas (
id_entrega INT AUTO_INCREMENT,
id_cosecha INT,
fecha_entrega DATE,
kilos_entregados INT,
PRIMARY KEY (id_entrega),
FOREIGN KEY (id_cosecha) REFERENCES cosechas(id_cosechas));

USE yerbateraHuber;

CREATE TABLE cliente(
id_cliente INT AUTO_INCREMENT,
nombre VARCHAR(70),
PRIMARY KEY (id_cliente));

CREATE TABLE ventas(
id_ventas INT AUTO_INCREMENT,
id_entrega INT,
id_cliente INT,
fecha_venta DATE,
monto DECIMAL(10,2),
metodo_pago VARCHAR(50),
PRIMARY KEY (id_ventas),
FOREIGN KEY (id_entrega) REFERENCES entregas(id_entrega),
FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente));

CREATE TABLE tareas(
id_tarea INT AUTO_INCREMENT,
id_lote INT,
id_personal INT,
descripcion VARCHAR(50),
fecha DATE,
PRIMARY KEY (id_tarea),
FOREIGN KEY (id_lote) REFERENCES lotes(id_lote),
FOREIGN KEY (id_personal) REFERENCES personal(id_personal));

#Correcciones del 13/12/2025

USE yerbaterahuber;

RENAME TABLE lotes TO lote;
RENAME TABLE personal TO persona;
RENAME TABLE cosechas TO cosecha;
RENAME TABLE entregas TO entrega;
RENAME TABLE ventas TO venta;
RENAME TABLE tareas TO tarea;

ALTER TABLE persona
MODIFY rol ENUM('Capataz', 'Cosechero', 'Administrativo', 'Encargado') NOT NULL;

#Entrega del 21/01/2026

USE yerbaterahuber;

CREATE TABLE log_auditoria_ventas (
    id_log INT AUTO_INCREMENT,
    id_venta INT,
    accion VARCHAR(20),
    usuario VARCHAR(50),
    fecha_hora DATETIME,
    PRIMARY KEY (id_log)
);

CREATE VIEW vw_produccion_por_lote AS
SELECT 
    l.nombre_lote,
    l.ubicacion,
    SUM(c.kilos_cosechados) AS total_kilos_historico
FROM lote l
JOIN cosecha c ON l.id_lote = c.id_lote
GROUP BY l.id_lote, l.nombre_lote, l.ubicacion;

CREATE VIEW vw_detalle_cosecha_completo AS
SELECT 
    c.id_cosechas,
    c.fecha_cosecha,
    l.nombre_lote,
    p.nombre_completo AS nombre_cosechero,
    c.kilos_cosechados
FROM cosecha c
JOIN lote l ON c.id_lote = l.id_lote
JOIN persona p ON c.id_personal = p.id_personal;

CREATE VIEW vw_ventas_vip AS
SELECT * FROM venta 
WHERE monto > (SELECT AVG(monto) FROM venta);

DELIMITER //
CREATE FUNCTION fn_calcular_rendimiento (p_id_cosecha INT) 
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE v_kilos INT;
    DECLARE v_hectareas DECIMAL(10,2);
    DECLARE v_rendimiento DECIMAL(10,2);

    SELECT kilos_cosechados INTO v_kilos 
    FROM cosecha WHERE id_cosechas = p_id_cosecha;

    SELECT l.hectareas INTO v_hectareas 
    FROM lote l
    JOIN cosecha c ON l.id_lote = c.id_lote
    WHERE c.id_cosechas = p_id_cosecha;

    IF v_hectareas > 0 THEN
        SET v_rendimiento = v_kilos / v_hectareas;
    ELSE
        SET v_rendimiento = 0;
    END IF;

    RETURN v_rendimiento;
END //

CREATE FUNCTION fn_antiguedad_empleado (p_id_personal INT)
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE v_fecha_inicio DATE;
    DECLARE v_antiguedad INT;

    SELECT fecha_inicio INTO v_fecha_inicio
    FROM persona
    WHERE id_personal = p_id_personal;

    SET v_antiguedad = TIMESTAMPDIFF(YEAR, v_fecha_inicio, CURDATE());

    RETURN v_antiguedad;
END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE sp_ordenar_ventas (IN p_campo_ordenamiento VARCHAR(20))
BEGIN
    IF p_campo_ordenamiento = 'monto' THEN
        SELECT * FROM venta ORDER BY monto DESC;
    ELSEIF p_campo_ordenamiento = 'fecha' THEN
        SELECT * FROM venta ORDER BY fecha_venta DESC;
    ELSE
        SELECT * FROM venta; 
    END IF;
END //

CREATE PROCEDURE sp_registrar_tarea (
    IN p_id_lote INT,
    IN p_id_personal INT,
    IN p_descripcion VARCHAR(50),
    IN p_fecha DATE
)
BEGIN
    INSERT INTO tarea (id_lote, id_personal, descripcion, fecha)
    VALUES (p_id_lote, p_id_personal, p_descripcion, p_fecha);
END //

DELIMITER ;

DELIMITER //

CREATE TRIGGER tr_auditoria_nueva_venta
AFTER INSERT ON venta
FOR EACH ROW
BEGIN
    INSERT INTO log_auditoria_ventas (id_venta, accion, usuario, fecha_hora)
    VALUES (NEW.id_ventas, 'INSERT', USER(), NOW());
END //

CREATE TRIGGER tr_validar_fecha_cosecha
BEFORE INSERT ON cosecha
FOR EACH ROW
BEGIN
    IF NEW.fecha_cosecha > CURDATE() THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Error: La fecha de cosecha no puede ser futura.';
    END IF;
END //

DELIMITER ;