-- Copia del esquema proporcionado. Solo para una base optativa_test nueva y aislada.
BEGIN;
CREATE TABLE usuario (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(120) NOT NULL,
    apellido_paterno VARCHAR(100),
    apellido_materno VARCHAR(100),
    telefono VARCHAR(20),
    correo VARCHAR(254) NOT NULL,
    contrasena_hash VARCHAR(255) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_usuario_nombre CHECK (length(btrim(nombre)) > 0),
    CONSTRAINT ck_usuario_correo CHECK (correo = lower(btrim(correo)) AND length(correo) > 3),
    CONSTRAINT ck_usuario_hash CHECK (length(btrim(contrasena_hash)) > 0)
);
CREATE UNIQUE INDEX uq_usuario_correo_normalizado ON usuario (lower(correo));
CREATE TABLE categoria (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT ck_categoria_nombre CHECK (length(btrim(nombre)) > 0)
);
CREATE UNIQUE INDEX uq_categoria_nombre_normalizado ON categoria (lower(btrim(nombre)));
CREATE TABLE emprendimiento (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    usuario_id BIGINT NOT NULL UNIQUE,
    categoria_id BIGINT NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    descripcion TEXT NOT NULL,
    telefono VARCHAR(30),
    direccion_referencia VARCHAR(255),
    horario_atencion VARCHAR(255),
    latitud NUMERIC(10,7) NOT NULL,
    longitud NUMERIC(10,7) NOT NULL,
    foto_lugar_ruta VARCHAR(500) NOT NULL,
    publicado BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_emprendimiento_usuario FOREIGN KEY (usuario_id) REFERENCES usuario(id),
    CONSTRAINT fk_emprendimiento_categoria FOREIGN KEY (categoria_id) REFERENCES categoria(id),
    CONSTRAINT ck_emprendimiento_nombre CHECK (length(btrim(nombre)) > 0),
    CONSTRAINT ck_emprendimiento_descripcion CHECK (length(btrim(descripcion)) > 0),
    CONSTRAINT ck_emprendimiento_latitud CHECK (latitud BETWEEN -90 AND 90),
    CONSTRAINT ck_emprendimiento_longitud CHECK (longitud BETWEEN -180 AND 180),
    CONSTRAINT ck_emprendimiento_foto CHECK (length(btrim(foto_lugar_ruta)) > 0)
);
CREATE INDEX ix_emprendimiento_categoria_publicado ON emprendimiento (categoria_id, publicado);
CREATE INDEX ix_emprendimiento_nombre ON emprendimiento (lower(nombre));
CREATE TABLE producto (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    emprendimiento_id BIGINT NOT NULL,
    cliente_uuid UUID NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    descripcion TEXT NOT NULL,
    precio NUMERIC(10,2) NOT NULL,
    foto_producto_ruta VARCHAR(500) NOT NULL,
    publicado BOOLEAN NOT NULL DEFAULT TRUE,
    alta_hash VARCHAR(64) NOT NULL,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_producto_emprendimiento FOREIGN KEY (emprendimiento_id) REFERENCES emprendimiento(id),
    CONSTRAINT uq_producto_cliente_uuid UNIQUE (emprendimiento_id, cliente_uuid),
    CONSTRAINT ck_producto_nombre CHECK (length(btrim(nombre)) > 0),
    CONSTRAINT ck_producto_descripcion CHECK (length(btrim(descripcion)) > 0),
    CONSTRAINT ck_producto_precio CHECK (precio >= 0),
    CONSTRAINT ck_producto_foto CHECK (length(btrim(foto_producto_ruta)) > 0),
    CONSTRAINT ck_producto_alta_hash CHECK (alta_hash ~ '^[0-9a-f]{64}$')
);
CREATE INDEX ix_producto_emprendimiento_publicado ON producto (emprendimiento_id, publicado);
INSERT INTO categoria (nombre) VALUES ('Artesanías'), ('Alimentos'), ('Belleza'), ('Otros');
COMMIT;
