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


-- Entrega final

USE yerbateraHuber;

CREATE TABLE hecho_rendimiento (
    id_hecho INT AUTO_INCREMENT PRIMARY KEY,
    id_lote INT,
    id_cliente INT,
    id_personal INT,
    fecha_proceso DATE,
    total_kilos_cosechados INT,
    total_monto_venta DECIMAL(15,2),
    rendimiento_por_hectarea DECIMAL(10,2),
    FOREIGN KEY (id_lote) REFERENCES lote(id_lote),
    FOREIGN KEY (id_cliente) REFERENCES cliente(id_cliente),
    FOREIGN KEY (id_personal) REFERENCES persona(id_personal)
);


CREATE VIEW vw_ranking_cosecheros AS
SELECT 
    p.nombre_completo,
    SUM(c.kilos_cosechados) AS kilos_totales,
    COUNT(c.id_cosechas) AS cantidad_jornadas
FROM persona p
JOIN cosecha c ON p.id_personal = c.id_personal
GROUP BY p.id_personal
ORDER BY kilos_totales DESC;


CREATE VIEW vw_resumen_ventas_cliente AS
SELECT 
    cl.nombre,
    COUNT(v.id_ventas) AS total_compras,
    SUM(v.monto) AS total_invertido
FROM cliente cl
JOIN venta v ON cl.id_cliente = v.id_cliente
GROUP BY cl.id_cliente;


-- datos de ejemplo para probar 
INSERT INTO lote (nombre_lote, hectareas, ubicacion, fecha_plantacion) VALUES
('La Agüita', 15.5, 'Oberá, Misiones', '2015-05-20'),
('El Timbó', 20.0, 'San Ignacio, Misiones', '2018-03-15'),
('Yerbal del Sol', 10.2, 'Apóstoles, Misiones', '2012-10-10'),
('Lote Frontera', 35.0, 'Andresito, Misiones', '2020-06-01'),
('Campo Seco', 12.0, 'Gobernador Virasoro, Corrientes', '2016-08-22');

INSERT INTO persona (nombre_completo, rol, fecha_inicio, estado) VALUES
('Juan Carlos Gonzalez', 'Capataz', '2010-02-01', 'Activo'),
('Mariela Sosa', 'Administrativo', '2019-11-15', 'Activo'),
('Pedro Iturrieta', 'Cosechero', '2022-04-10', 'Activo'),
('Ramón Maidana', 'Cosechero', '2021-05-20', 'Activo'),
('Aníbal Fernandez', 'Encargado', '2015-01-10', 'Activo');

INSERT INTO cliente (nombre) VALUES
('Cooperativa Agrícola de Oberá'),
('Distribuidora El Mate S.A.'),
('Supermercados Regionales'),
('Exportadora del Litoral'),
('Molino Yerba Pura');

INSERT INTO cosecha (id_lote, id_personal, fecha_cosecha, kilos_cosechados) VALUES
(1, 3, '2024-05-10', 5000),
(1, 4, '2024-05-11', 4800),
(2, 3, '2024-06-01', 7200),
(3, 4, '2024-06-15', 3500),
(5, 3, '2024-07-05', 4100);

INSERT INTO entrega (id_cosecha, fecha_entrega, kilos_entregados) VALUES
(1, '2024-05-12', 4950), -- Se pierde un poco en el transporte
(2, '2024-05-13', 4780),
(3, '2024-06-03', 7150),
(4, '2024-06-16', 3450),
(5, '2024-07-06', 4050);

INSERT INTO venta (id_entrega, id_cliente, fecha_venta, monto, metodo_pago) VALUES
(1, 1, '2024-05-20', 1500000.00, 'Transferencia'),
(2, 2, '2024-05-22', 1450000.00, 'Efectivo'),
(3, 1, '2024-06-10', 2100000.00, 'Cheque'),
(4, 3, '2024-06-25', 1050000.00, 'Transferencia'),
(5, 5, '2024-07-15', 1200000.00, 'Transferencia');

INSERT INTO tarea (id_lote, id_personal, descripcion, fecha) VALUES
(1, 1, 'Control de plagas', '2024-01-10'),
(2, 1, 'Fertilización foliar', '2024-02-15'),
(3, 4, 'Limpieza de malezas', '2024-03-20');

INSERT INTO hecho_rendimiento (id_lote, id_cliente, id_personal, fecha_proceso, total_kilos_cosechados, total_monto_venta, rendimiento_por_hectarea) VALUES
(1, 1, 3, '2024-05-20', 9800, 2950000.00, 632.25),
(2, 2, 3, '2024-06-10', 7200, 2100000.00, 360.00);

-- vistas

SELECT * FROM vw_produccion_por_lote;

SELECT * FROM vw_ranking_cosecheros;

CALL sp_ordenar_ventas('monto');

SELECT nombre_completo, fn_antiguedad_empleado(id_personal) AS años FROM persona;

-- más datos para probar

USE yerbaterahuber;

INSERT INTO cosecha (id_lote, id_personal, fecha_cosecha, kilos_cosechados) VALUES
(1, 3, '2025-01-15', 2500),
(2, 4, '2025-02-10', 3800),
(3, 3, '2025-03-05', 6000), 
(4, 4, '2025-04-12', 5500),
(5, 3, '2025-05-20', 3200),
(1, 4, '2025-06-15', 1500),
(2, 3, '2025-07-22', 1200),
(3, 4, '2025-08-10', 2800),
(4, 3, '2025-09-05', 4100);

SELECT 
    DATE_FORMAT(fecha_cosecha, '%Y-%m') AS Mes, 
    SUM(kilos_cosechados) AS Kilos_Totales
FROM cosecha
GROUP BY Mes
ORDER BY Mes;


-- más datos, así se genera un gráfico copado


USE yerbaterahuber;


-- (esto de abajo lo hice con ayuda de IA, ya que no sabía cómo hacerlo sin tener que insertar 120 values)

DELIMITER //

CREATE PROCEDURE sp_generar_datos_historicos()
BEGIN
    DECLARE v_fecha DATE DEFAULT '2016-01-01';
    DECLARE v_kilos INT;
    DECLARE v_mes INT;

    WHILE v_fecha <= CURDATE() DO
        SET v_mes = MONTH(v_fecha);
        
        -- Simulamción estacionalidad: En marzo/abril se cosecha más (pico)
        IF v_mes IN (3, 4, 5) THEN
            SET v_kilos = 6000 + (FLOOR(RAND() * 2000)); 
        ELSE
            SET v_kilos = 2500 + (FLOOR(RAND() * 1500));
        END IF;

        -- Insertamos en cosecha (rotando entre los 5 lotes y 2 cosecheros)
        INSERT INTO cosecha (id_lote, id_personal, fecha_cosecha, kilos_cosechados)
        VALUES (
            (FLOOR(1 + RAND() * 5)),     -- Lote aleatorio del 1 al 5
            (FLOOR(3 + RAND() * 2)),     -- Cosecheros (IDs 3 y 4)
            v_fecha, 
            v_kilos
        );

        -- Avanzamos un mes
        SET v_fecha = DATE_ADD(v_fecha, INTERVAL 1 MONTH);
    END WHILE;
END //

DELIMITER ;

CALL sp_generar_datos_historicos();

DROP PROCEDURE sp_generar_datos_historicos;

SELECT 
    YEAR(fecha_cosecha) AS Anio,
    SUM(kilos_cosechados) AS Kilos_Anuales
FROM cosecha
GROUP BY Anio
ORDER BY Anio;