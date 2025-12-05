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