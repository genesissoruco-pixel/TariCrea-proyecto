--
-- PostgreSQL database dump
--

\restrict oJmQQ3H426J98b3cNbfFi8VTI8JgrHYsmTuFdjdXkBwJo4fzk9Z6Mxx6opbKJX2

-- Dumped from database version 16.16
-- Dumped by pg_dump version 16.16

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: categoria; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categoria (
    id bigint NOT NULL,
    nombre character varying(100) NOT NULL,
    activa boolean DEFAULT true NOT NULL,
    CONSTRAINT ck_categoria_nombre CHECK ((length(btrim((nombre)::text)) > 0))
);


--
-- Name: categoria_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.categoria ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.categoria_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: emprendimiento; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.emprendimiento (
    id bigint NOT NULL,
    usuario_id bigint NOT NULL,
    categoria_id bigint NOT NULL,
    nombre character varying(150) NOT NULL,
    descripcion text NOT NULL,
    telefono character varying(30),
    direccion_referencia character varying(255),
    horario_atencion character varying(255),
    latitud numeric(10,7) NOT NULL,
    longitud numeric(10,7) NOT NULL,
    foto_lugar_ruta character varying(500) NOT NULL,
    publicado boolean DEFAULT true NOT NULL,
    creado_en timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    actualizado_en timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_emprendimiento_descripcion CHECK ((length(btrim(descripcion)) > 0)),
    CONSTRAINT ck_emprendimiento_foto CHECK ((length(btrim((foto_lugar_ruta)::text)) > 0)),
    CONSTRAINT ck_emprendimiento_latitud CHECK (((latitud >= ('-90'::integer)::numeric) AND (latitud <= (90)::numeric))),
    CONSTRAINT ck_emprendimiento_longitud CHECK (((longitud >= ('-180'::integer)::numeric) AND (longitud <= (180)::numeric))),
    CONSTRAINT ck_emprendimiento_nombre CHECK ((length(btrim((nombre)::text)) > 0))
);


--
-- Name: emprendimiento_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.emprendimiento ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.emprendimiento_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: producto; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.producto (
    id bigint NOT NULL,
    emprendimiento_id bigint NOT NULL,
    cliente_uuid uuid NOT NULL,
    nombre character varying(150) NOT NULL,
    descripcion text NOT NULL,
    precio numeric(10,2) NOT NULL,
    foto_producto_ruta character varying(500) NOT NULL,
    publicado boolean DEFAULT true NOT NULL,
    alta_hash character varying(64) NOT NULL,
    creado_en timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    actualizado_en timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_producto_alta_hash CHECK (((alta_hash)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT ck_producto_descripcion CHECK ((length(btrim(descripcion)) > 0)),
    CONSTRAINT ck_producto_foto CHECK ((length(btrim((foto_producto_ruta)::text)) > 0)),
    CONSTRAINT ck_producto_nombre CHECK ((length(btrim((nombre)::text)) > 0)),
    CONSTRAINT ck_producto_precio CHECK ((precio >= (0)::numeric))
);


--
-- Name: producto_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.producto ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.producto_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: usuario; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.usuario (
    id bigint NOT NULL,
    nombre character varying(120) NOT NULL,
    apellido_paterno character varying(100),
    apellido_materno character varying(100),
    telefono character varying(20),
    correo character varying(254) NOT NULL,
    contrasena_hash character varying(255) NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    creado_en timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    actualizado_en timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT ck_usuario_correo CHECK ((((correo)::text = lower(btrim((correo)::text))) AND (length((correo)::text) > 3))),
    CONSTRAINT ck_usuario_hash CHECK ((length(btrim((contrasena_hash)::text)) > 0)),
    CONSTRAINT ck_usuario_nombre CHECK ((length(btrim((nombre)::text)) > 0))
);


--
-- Name: usuario_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.usuario ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.usuario_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Data for Name: categoria; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.categoria (id, nombre, activa) FROM stdin;
1	Artesanías	t
2	Alimentos	t
3	Belleza	t
4	Otros	t
\.


--
-- Data for Name: emprendimiento; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.emprendimiento (id, usuario_id, categoria_id, nombre, descripcion, telefono, direccion_referencia, horario_atencion, latitud, longitud, foto_lugar_ruta, publicado, creado_en, actualizado_en) FROM stdin;
1	1	1	Entre Lanas	Todo tipo de tejidos con lana	78645135	B el trigal	3:00pm a 6:00pm	-21.5076040	-64.7163086	emprendimientos/350a5418-a24a-4ec4-8b6d-b51250c2e8f7.png	t	2026-11-17 11:25:14.972202-04	2026-11-17 11:25:14.972202-04
2	2	1	Genelis	Costura en general	60253737	B/4 de marzo	15:30 a 19:30	-21.5099762	-64.7137630	emprendimientos/c91db1ca-048c-4c1f-87ff-0319f2e4b8ba.png	t	2026-11-17 11:33:15.283783-04	2026-11-17 11:38:27.106147-04
\.


--
-- Data for Name: producto; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.producto (id, emprendimiento_id, cliente_uuid, nombre, descripcion, precio, foto_producto_ruta, publicado, alta_hash, creado_en, actualizado_en) FROM stdin;
1	1	aa4833d0-89e0-4884-a7db-d575ce76737b	Girasol	Girasol de 30 cm de chenille	30.00	productos/010cd956-9cfd-4661-8d3c-e9d5103ebe34.png	t	e0a77be5829edb6d83bd11f6100fe25d5058a595494c257ae931e7b817669a23	2026-11-17 11:26:20.828697-04	2026-11-17 11:26:20.828697-04
2	1	9aea0eab-b3a7-445c-aad7-6cc6f8240883	Muñeca	Muñeca tejida de chenille de 35 cm	80.00	productos/f529da85-a6a4-4a51-b6ca-7660657bbc44.png	t	87e31321399cd3c762e95938887308fa1dc7ce5606095e7785293c906e0a6381	2026-11-17 11:27:42.507493-04	2026-11-17 11:27:42.507493-04
3	2	754e1955-8c75-4c38-a71d-a379515fd1dc	Bolso agenda	Bolso hobo tamaño agenda	65.00	productos/4f75a9fc-442a-4ae5-b87b-e9557699aef3.png	t	d11892ed48797855219a64cc92fb470c619118864fcead8b637ba255e2e7b3db	2026-11-17 11:34:30.133456-04	2026-11-17 11:34:30.133456-04
4	2	413b46c4-da4b-4ae4-ac9f-dd21bcee15f4	Bolso Hobo	Tamaño carta	75.00	productos/46862c9b-02c4-4834-9468-51dbdf3a7f63.png	t	a0488f0aa0baf6aaac9c411e6f7232b4f4759177053261037a272b7be5ae0b3b	2026-11-17 11:35:35.758946-04	2026-11-17 11:35:35.758946-04
\.


--
-- Data for Name: usuario; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.usuario (id, nombre, apellido_paterno, apellido_materno, telefono, correo, contrasena_hash, activo, creado_en, actualizado_en) FROM stdin;
1	Yuliana	Reyes	García	75464387	yuli@gmail.com	$2a$10$wp33f3tu1F.qh5TBE0ZLWOqVKwlhOjVLQGsJtg7b9nAnR2VLm8u9a	t	2026-11-17 11:22:43.334176-04	2026-11-17 11:22:43.334176-04
2	Genesis	Soruco	Patty	60253737	genesis@gmail.com	$2a$10$WxQnhzfTKwlDvAzMyO42R.nzQJRfjWCsgsDKFypeAUZQlS3Yj82b6	t	2026-11-17 11:29:51.1665-04	2026-11-17 11:29:51.1665-04
\.


--
-- Name: categoria_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.categoria_id_seq', 4, true);


--
-- Name: emprendimiento_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.emprendimiento_id_seq', 2, true);


--
-- Name: producto_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.producto_id_seq', 4, true);


--
-- Name: usuario_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.usuario_id_seq', 2, true);


--
-- Name: categoria categoria_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categoria
    ADD CONSTRAINT categoria_pkey PRIMARY KEY (id);


--
-- Name: emprendimiento emprendimiento_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.emprendimiento
    ADD CONSTRAINT emprendimiento_pkey PRIMARY KEY (id);


--
-- Name: emprendimiento emprendimiento_usuario_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.emprendimiento
    ADD CONSTRAINT emprendimiento_usuario_id_key UNIQUE (usuario_id);


--
-- Name: producto producto_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.producto
    ADD CONSTRAINT producto_pkey PRIMARY KEY (id);


--
-- Name: producto uq_producto_cliente_uuid; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.producto
    ADD CONSTRAINT uq_producto_cliente_uuid UNIQUE (emprendimiento_id, cliente_uuid);


--
-- Name: usuario usuario_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuario_pkey PRIMARY KEY (id);


--
-- Name: ix_emprendimiento_categoria_publicado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_emprendimiento_categoria_publicado ON public.emprendimiento USING btree (categoria_id, publicado);


--
-- Name: ix_emprendimiento_nombre; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_emprendimiento_nombre ON public.emprendimiento USING btree (lower((nombre)::text));


--
-- Name: ix_producto_emprendimiento_publicado; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_producto_emprendimiento_publicado ON public.producto USING btree (emprendimiento_id, publicado);


--
-- Name: uq_categoria_nombre_normalizado; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_categoria_nombre_normalizado ON public.categoria USING btree (lower(btrim((nombre)::text)));


--
-- Name: uq_usuario_correo_normalizado; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_usuario_correo_normalizado ON public.usuario USING btree (lower((correo)::text));


--
-- Name: emprendimiento fk_emprendimiento_categoria; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.emprendimiento
    ADD CONSTRAINT fk_emprendimiento_categoria FOREIGN KEY (categoria_id) REFERENCES public.categoria(id);


--
-- Name: emprendimiento fk_emprendimiento_usuario; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.emprendimiento
    ADD CONSTRAINT fk_emprendimiento_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);


--
-- Name: producto fk_producto_emprendimiento; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.producto
    ADD CONSTRAINT fk_producto_emprendimiento FOREIGN KEY (emprendimiento_id) REFERENCES public.emprendimiento(id);


--
-- PostgreSQL database dump complete
--

\unrestrict oJmQQ3H426J98b3cNbfFi8VTI8JgrHYsmTuFdjdXkBwJo4fzk9Z6Mxx6opbKJX2

