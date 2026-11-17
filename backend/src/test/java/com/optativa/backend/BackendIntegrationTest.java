package com.optativa.backend;

import com.optativa.backend.exception.ApiException;
import com.optativa.backend.service.ImagenService;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.*;
import org.springframework.test.web.servlet.request.MockMultipartHttpServletRequestBuilder;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.transaction.PlatformTransactionManager;
import tools.jackson.databind.*;
import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test")
@EnabledIfEnvironmentVariable(named = "TEST_DB_URL", matches = "jdbc:postgresql://(127\\.0\\.0\\.1|localhost):[0-9]+/optativa_test")
class BackendIntegrationTest {
    private static final AtomicInteger SIGUIENTE_IP = new AtomicInteger();
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper mapper;
    @Autowired JdbcTemplate jdbc;
    @Autowired ImagenService imagenes;
    @Autowired PlatformTransactionManager transacciones;
    private byte[] png;
    private String ip;

    @BeforeEach void preparar() throws Exception {
        assertEquals("optativa_test", jdbc.queryForObject("select current_database()", String.class));
        jdbc.execute("TRUNCATE producto, emprendimiento, usuario RESTART IDENTITY CASCADE");
        jdbc.update("update categoria set activa=true");
        png = imagen(2, 2);
        ip = "192.0.2." + SIGUIENTE_IP.incrementAndGet();
    }
    private byte[] imagen(int ancho, int alto) throws IOException {
        return imagen(ancho, alto, "png");
    }
    private byte[] imagen(int ancho, int alto, String formato) throws IOException {
        var salida = new ByteArrayOutputStream();
        assertTrue(ImageIO.write(new BufferedImage(ancho, alto, BufferedImage.TYPE_INT_RGB), formato, salida));
        return salida.toByteArray();
    }
    private JsonNode datos(MvcResult resultado) { return mapper.readTree(resultado.getResponse().getContentAsByteArray()).get("data"); }
    private String cuenta(String correo) throws Exception {
        mvc.perform(post("/api/auth/registro").contentType("application/json")
                .with(r -> { r.setRemoteAddr(ip); return r; })
                .content(mapper.writeValueAsString(Map.of("nombre", "Ana", "correo", correo,
                        "apellidoPaterno", "Rojas", "apellidoMaterno", "Vargas",
                        "telefono", "+59170000000", "contrasena", "prueba-segura-123"))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.apellidoPaterno").value("Rojas"))
                .andExpect(jsonPath("$.data.apellidoMaterno").value("Vargas"))
                .andExpect(jsonPath("$.data.telefono").value("+59170000000"));
        return datos(mvc.perform(post("/api/auth/login").contentType("application/json")
                .with(r -> { r.setRemoteAddr(ip); return r; })
                .content(mapper.writeValueAsString(Map.of("correo", correo, "contrasena", "prueba-segura-123"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.usuario.apellidoPaterno").value("Rojas"))
                .andExpect(jsonPath("$.data.usuario.apellidoMaterno").value("Vargas"))
                .andExpect(jsonPath("$.data.usuario.telefono").value("+59170000000"))
                .andReturn()).get("token").asText();
    }
    private String negocioDatos(boolean publicado) {
        return "{\"categoriaId\":1,\"nombre\":\"Taller Sur\",\"descripcion\":\"Cerámica local\",\"direccionReferencia\":\"Frente a la plaza\",\"horarioAtencion\":\"09:00 a 17:00\",\"latitud\":-21.5355,\"longitud\":-64.7296,\"publicado\":" + publicado + "}";
    }
    private MockMultipartHttpServletRequestBuilder multipartDatos(String ruta, String datos, boolean foto) {
        var request = multipart(ruta).file(new MockMultipartFile("datos", "", "application/json", datos.getBytes(StandardCharsets.UTF_8)));
        if (foto) request.file(new MockMultipartFile("foto", "camara.png", "image/png", png));
        return request;
    }
    private JsonNode negocio(String token) throws Exception {
        return datos(mvc.perform(multipartDatos("/api/emprendimientos", negocioDatos(true), true).header("Authorization", "Bearer " + token))
                .andExpect(status().isCreated()).andReturn());
    }
    private String productoDatos(UUID uuid, int precio) {
        return "{\"cliente_uuid\":\"" + uuid + "\",\"nombre\":\"Taza\",\"descripcion\":\"Cerámica\",\"precio\":" + precio + ",\"publicado\":true}";
    }
    private MvcResult alta(String token, UUID uuid, int precio, int estado) throws Exception {
        return mvc.perform(multipartDatos("/api/emprendimientos/mio/productos", productoDatos(uuid, precio), true)
                .header("Authorization", "Bearer " + token)).andExpect(status().is(estado)).andReturn();
    }
    private MockMultipartHttpServletRequestBuilder putMultipart(String ruta, String datos, boolean foto) {
        var request = multipartDatos(ruta, datos, foto);
        request.with(r -> { r.setMethod("PUT"); return r; });
        return request;
    }

    @Test void registroCorreoUnicoBcryptYPerfil() throws Exception {
        String token = cuenta("ANA@example.com");
        assertTrue(jdbc.queryForObject("select contrasena_hash from usuario", String.class).startsWith("$2"));
        mvc.perform(get("/api/auth/me").header("Authorization", "Bearer " + token)).andExpect(status().isOk())
                .andExpect(jsonPath("$.data.correo").value("ana@example.com"))
                .andExpect(jsonPath("$.data.apellidoPaterno").value("Rojas"))
                .andExpect(jsonPath("$.data.apellidoMaterno").value("Vargas"))
                .andExpect(jsonPath("$.data.telefono").value("+59170000000"))
                .andExpect(jsonPath("$.data.contrasenaHash").doesNotExist());
        mvc.perform(post("/api/auth/registro").contentType("application/json")
                .content("{\"nombre\":\"Otra\",\"apellidoPaterno\":\"Rojas\",\"apellidoMaterno\":\"Vargas\",\"telefono\":\"70000000\",\"correo\":\"ana@example.com\",\"contrasena\":\"prueba-segura-123\"}"))
                .andExpect(status().isConflict());
        mvc.perform(post("/api/auth/registro").contentType("application/json")
                .content("{\"nombre\":\"Otra\",\"apellidoPaterno\":\"Rojas\",\"apellidoMaterno\":\"Vargas\",\"telefono\":\"70000000\",\"correo\":\"sin-correo\",\"contrasena\":\"corta\"}"))
                .andExpect(status().isBadRequest());
        mvc.perform(post("/api/auth/registro").contentType("application/json")
                .with(r -> { r.setRemoteAddr(ip); return r; })
                .content("{\"nombre\":\"Ana\",\"correo\":\"nueva@example.com\",\"contrasena\":\"prueba-segura-123\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.data.apellidoPaterno").exists())
                .andExpect(jsonPath("$.data.apellidoMaterno").exists())
                .andExpect(jsonPath("$.data.telefono").exists());
        jdbc.update("update usuario set apellido_paterno=null, apellido_materno=null, telefono=null");
        mvc.perform(get("/api/auth/me").header("Authorization", "Bearer " + token)).andExpect(status().isOk())
                .andExpect(jsonPath("$.data.apellidoPaterno").hasJsonPath())
                .andExpect(jsonPath("$.data.apellidoPaterno").doesNotExist());
    }
    @Test void rechazaCredencialesCuentaInactivaTokenInvalidoYVencido() throws Exception {
        String token = cuenta("ana@example.com");
        mvc.perform(post("/api/auth/login").contentType("application/json")
                .content("{\"correo\":\"ana@example.com\",\"contrasena\":\"incorrecta\"}"))
                .andExpect(status().isUnauthorized());
        mvc.perform(get("/api/auth/me")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/auth/me").header("Authorization", "Bearer falso")).andExpect(status().isUnauthorized());
        String vencido = Jwts.builder().issuer("optativa-iv").subject("1").issuedAt(Date.from(Instant.now().minusSeconds(120)))
                .expiration(Date.from(Instant.now().minusSeconds(60)))
                .signWith(Keys.hmacShaKeyFor("solo-para-pruebas-aisladas-clave-de-64-caracteres-no-produccion-123456".getBytes(StandardCharsets.UTF_8))).compact();
        mvc.perform(get("/api/auth/me").header("Authorization", "Bearer " + vencido)).andExpect(status().isUnauthorized());
        jdbc.update("update usuario set activo=false");
        mvc.perform(get("/api/auth/me").header("Authorization", "Bearer " + token)).andExpect(status().isUnauthorized());
        mvc.perform(post("/api/auth/login").contentType("application/json")
                .content("{\"correo\":\"ana@example.com\",\"contrasena\":\"prueba-segura-123\"}"))
                .andExpect(status().isUnauthorized());
    }
    @Test void negocioUnicoConFotoYEdicionPropia() throws Exception {
        String token = cuenta("ana@example.com");
        JsonNode e = negocio(token);
        assertEquals("Frente a la plaza", e.get("direccionReferencia").asText());
        assertEquals("09:00 a 17:00", e.get("horarioAtencion").asText());
        String fotoAnterior = e.get("fotoUrl").asText();
        mvc.perform(get(fotoAnterior)).andExpect(status().isOk()).andExpect(content().contentType("image/png"));
        mvc.perform(multipartDatos("/api/emprendimientos", negocioDatos(true), true).header("Authorization", "Bearer " + token))
                .andExpect(status().isConflict());
        var editado = datos(mvc.perform(putMultipart("/api/emprendimientos/mio", negocioDatos(true).replace("Taller Sur", "Taller Norte")
                .replace("Frente a la plaza", "Al lado del mercado").replace("09:00 a 17:00", "10:00 a 18:00"), true)
                .header("Authorization", "Bearer " + token)).andExpect(status().isOk()).andReturn());
        assertEquals("Al lado del mercado", editado.get("direccionReferencia").asText());
        assertEquals("10:00 a 18:00", editado.get("horarioAtencion").asText());
        assertNotEquals(fotoAnterior, editado.get("fotoUrl").asText());
        assertFalse(Files.exists(Path.of("target/test-uploads", fotoAnterior.replace("/api/imagenes/", ""))));
        assertTrue(Instant.parse(editado.get("actualizadoEn").asText()).isAfter(Instant.parse(e.get("creadoEn").asText())));
        mvc.perform(get("/api/public/emprendimientos/" + e.get("id").asLong())).andExpect(status().isOk())
                .andExpect(jsonPath("$.data.direccionReferencia").value("Al lado del mercado"))
                .andExpect(jsonPath("$.data.horarioAtencion").value("10:00 a 18:00"));
        mvc.perform(get("/api/public/emprendimientos").param("nombre", "norte")).andExpect(status().isOk())
                .andExpect(jsonPath("$.data.total").value(1))
                .andExpect(jsonPath("$.data.items[0].direccionReferencia").value("Al lado del mercado"))
                .andExpect(jsonPath("$.data.items[0].horarioAtencion").value("10:00 a 18:00"));
        mvc.perform(get("/api/public/emprendimientos").param("nombre", "%")).andExpect(status().isOk()).andExpect(jsonPath("$.data.total").value(0));
    }
    @Test void validaGpsCategoriaYCamposInmutables() throws Exception {
        String token = cuenta("ana@example.com");
        String sinCamposNuevos = negocioDatos(true)
                .replace("\"direccionReferencia\":\"Frente a la plaza\",", "")
                .replace("\"horarioAtencion\":\"09:00 a 17:00\",", "");
        mvc.perform(multipartDatos("/api/emprendimientos", sinCamposNuevos, true)
                .header("Authorization", "Bearer " + token)).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.data.direccionReferencia").exists())
                .andExpect(jsonPath("$.data.horarioAtencion").exists());
        mvc.perform(multipartDatos("/api/emprendimientos", negocioDatos(true).replace("-21.5355", "91"), true)
                .header("Authorization", "Bearer " + token)).andExpect(status().isBadRequest());
        mvc.perform(multipartDatos("/api/emprendimientos", negocioDatos(true).replace("\"categoriaId\":1", "\"categoriaId\":999"), true)
                .header("Authorization", "Bearer " + token)).andExpect(status().isBadRequest());
        jdbc.update("update categoria set activa=false where id=1");
        mvc.perform(multipartDatos("/api/emprendimientos", negocioDatos(true), true).header("Authorization", "Bearer " + token)).andExpect(status().isBadRequest());
        jdbc.update("update categoria set activa=true where id=1");
        negocio(token);
        String otro = cuenta("otra@example.com");
        mvc.perform(putMultipart("/api/emprendimientos/mio", negocioDatos(true).replace("}", ",\"usuario_id\":1}"), false)
                .header("Authorization", "Bearer " + otro)).andExpect(status().isBadRequest());
        mvc.perform(putMultipart("/api/emprendimientos/mio", negocioDatos(true), false).header("Authorization", "Bearer " + otro))
                .andExpect(status().isNotFound());
        mvc.perform(putMultipart("/api/emprendimientos/mio", sinCamposNuevos, false)
                .header("Authorization", "Bearer " + token)).andExpect(status().isOk())
                .andExpect(jsonPath("$.data.direccionReferencia").value("Frente a la plaza"))
                .andExpect(jsonPath("$.data.horarioAtencion").value("09:00 a 17:00"));
        jdbc.update("update emprendimiento set direccion_referencia=null, horario_atencion=null");
        mvc.perform(get("/api/emprendimientos/mio").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.direccionReferencia").hasJsonPath())
                .andExpect(jsonPath("$.data.direccionReferencia").doesNotExist())
                .andExpect(jsonPath("$.data.horarioAtencion").hasJsonPath())
                .andExpect(jsonPath("$.data.horarioAtencion").doesNotExist());
        assertEquals(1, jdbc.queryForObject("select count(*) from emprendimiento", Integer.class));
    }
    @Test void productoCeroIdempotenciaConflictoYReintentoTrasEdicion() throws Exception {
        String token = cuenta("ana@example.com"); negocio(token);
        UUID uuid = UUID.randomUUID();
        JsonNode primero = datos(alta(token, uuid, 0, 201));
        String ruta = primero.get("fotoUrl").asText();
        assertEquals(primero.get("id"), datos(alta(token, uuid, 0, 200)).get("id"));
        assertEquals(ruta, datos(alta(token, uuid, 0, 200)).get("fotoUrl").asText());
        alta(token, uuid, 1, 409);
        mvc.perform(multipartDatos("/api/emprendimientos/mio/productos", productoDatos(uuid, 0), false)
                .file(new MockMultipartFile("foto", "otra.png", "image/png", imagen(3, 3)))
                .header("Authorization", "Bearer " + token)).andExpect(status().isConflict());
        alta(token, UUID.randomUUID(), -1, 400);
        String cambios = "{\"nombre\":\"Taza nueva\",\"descripcion\":\"Otra descripción\",\"precio\":9.50,\"publicado\":true}";
        mvc.perform(putMultipart("/api/emprendimientos/mio/productos/" + primero.get("id").asLong(), cambios, false)
                .header("Authorization", "Bearer " + token)).andExpect(status().isOk());
        assertEquals(primero.get("id"), datos(alta(token, uuid, 0, 200)).get("id"));
        assertEquals(1, jdbc.queryForObject("select count(*) from producto", Integer.class));
        assertTrue(jdbc.queryForObject("select alta_hash from producto", String.class).matches("[0-9a-f]{64}"));
    }
    @Test void propiedadPublicacionPaginacionYFotoOculta() throws Exception {
        String token = cuenta("ana@example.com"); JsonNode negocio = negocio(token);
        JsonNode producto = datos(alta(token, UUID.randomUUID(), 10, 201));
        String otro = cuenta("otra@example.com"); negocio(otro);
        String cambios = "{\"nombre\":\"Taza\",\"descripcion\":\"Cerámica\",\"precio\":10,\"publicado\":false}";
        String ruta = "/api/emprendimientos/mio/productos/" + producto.get("id").asLong();
        var ajeno = mvc.perform(putMultipart(ruta, cambios, false).header("Authorization", "Bearer " + otro))
                .andExpect(status().isNotFound()).andReturn().getResponse();
        var inexistente = mvc.perform(putMultipart("/api/emprendimientos/mio/productos/9999", cambios, false)
                .header("Authorization", "Bearer " + otro)).andExpect(status().isNotFound()).andReturn().getResponse();
        assertEquals(mapper.readTree(ajeno.getContentAsByteArray()), mapper.readTree(inexistente.getContentAsByteArray()));
        String fotoPrivada = datos(mvc.perform(putMultipart(ruta, cambios, false).header("Authorization", "Bearer " + token))
                .andExpect(status().isOk()).andReturn()).get("fotoUrl").asText();
        mvc.perform(get("/api/public/emprendimientos/" + negocio.get("id").asLong() + "/productos"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.total").value(0));
        mvc.perform(get(producto.get("fotoUrl").asText())).andExpect(status().isNotFound());
        verificarFotoPrivada(fotoPrivada, token, otro);
        mvc.perform(get("/api/emprendimientos/mio/productos").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.total").value(1));
        mvc.perform(get("/api/public/emprendimientos").param("size", "51")).andExpect(status().isBadRequest());
        String fotoNegocio = datos(mvc.perform(putMultipart("/api/emprendimientos/mio", negocioDatos(false), false)
                .header("Authorization", "Bearer " + token)).andExpect(status().isOk()).andReturn()).get("fotoUrl").asText();
        verificarFotoPrivada(fotoNegocio, token, otro);
        mvc.perform(get(negocio.get("fotoUrl").asText())).andExpect(status().isNotFound());
        mvc.perform(get("/api/public/emprendimientos/" + negocio.get("id").asLong())).andExpect(status().isNotFound());
    }

    private void verificarFotoPrivada(String ruta, String propio, String ajeno) throws Exception {
        assertTrue(ruta.startsWith("/api/imagenes-privadas/"));
        mvc.perform(get(ruta)).andExpect(status().isUnauthorized());
        mvc.perform(get(ruta).header("Authorization", "Bearer " + ajeno)).andExpect(status().isNotFound());
        mvc.perform(get(ruta).header("Authorization", "Bearer " + propio))
                .andExpect(status().isOk()).andExpect(content().contentType("image/png"));
    }

    @Test void consultaMiEmprendimientoAislaDosCuentas() throws Exception {
        String ruta = "/api/emprendimientos/mio";
        mvc.perform(get(ruta)).andExpect(status().isUnauthorized());
        String primero = cuenta("primero@example.com");
        String segundo = cuenta("segundo@example.com");
        long idPrimero = negocio(primero).get("id").asLong();
        mvc.perform(get(ruta).header("Authorization", "Bearer " + segundo)).andExpect(status().isNotFound());
        long idSegundo = negocio(segundo).get("id").asLong();
        assertNotEquals(idPrimero, idSegundo);
        mvc.perform(get(ruta).header("Authorization", "Bearer " + primero))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.id").value(idPrimero));
        mvc.perform(get(ruta).header("Authorization", "Bearer " + segundo))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data.id").value(idSegundo));
    }

    @Test void limitaLoginYRegistroPorIpConRetryAfter() throws Exception {
        String token = cuenta("ana@example.com");
        String login = "{\"correo\":\"ana@example.com\",\"contrasena\":\"incorrecta\"}";
        String registro = "{\"nombre\":\"Ana\",\"apellidoPaterno\":\"Rojas\",\"apellidoMaterno\":\"Vargas\",\"telefono\":\"70000000\",\"correo\":\"ana@example.com\",\"contrasena\":\"prueba-segura-123\"}";
        verificarLimite("/api/auth/login", login, 19, 401);
        verificarLimite("/api/auth/registro", registro, 9, 409);
        mvc.perform(get("/api/auth/me").header("Authorization", "Bearer " + token)).andExpect(status().isOk());
        mvc.perform(post("/api/auth/login").contentType("application/json")
                .content("{\"correo\":\"ana@example.com\",\"contrasena\":\"prueba-segura-123\"}")
                .with(r -> { r.setRemoteAddr("198.51.100.99"); return r; })).andExpect(status().isOk());
    }

    private void verificarLimite(String ruta, String cuerpo, int restantes, int estado) throws Exception {
        for (int i = 0; i < restantes; i++) {
            mvc.perform(post(ruta).contentType("application/json").content(cuerpo)
                    .with(r -> { r.setRemoteAddr(ip); return r; })).andExpect(status().is(estado));
        }
        mvc.perform(post(ruta).contentType("application/json").content(cuerpo)
                .with(r -> { r.setRemoteAddr(ip); return r; }))
                .andExpect(status().isTooManyRequests()).andExpect(header().exists("Retry-After"))
                .andExpect(jsonPath("$.success").value(false));
    }

    @Test void rollbackDeReemplazoConservaReferenciasYArchivosAnteriores() throws Exception {
        String token = cuenta("ana@example.com");
        String fotoNegocio = negocio(token).get("fotoUrl").asText();
        JsonNode producto = datos(alta(token, UUID.randomUUID(), 10, 201));
        String fotoProducto = producto.get("fotoUrl").asText();
        String rutaProducto = "/api/emprendimientos/mio/productos/" + producto.get("id").asLong();
        String cambios = "{\"nombre\":\"Nueva taza\",\"descripcion\":\"Cerámica\",\"precio\":10,\"publicado\":true}";
        Set<Path> archivosAntes = archivosDeFotos();
        new TransactionTemplate(transacciones).executeWithoutResult(estado -> {
            try {
                mvc.perform(putMultipart("/api/emprendimientos/mio", negocioDatos(true), true)
                        .header("Authorization", "Bearer " + token)).andExpect(status().isOk());
                mvc.perform(putMultipart(rutaProducto, cambios, true)
                        .header("Authorization", "Bearer " + token)).andExpect(status().isOk());
                assertEquals(archivosAntes.size() + 2, archivosDeFotos().size());
                assertTrue(archivosDeFotos().containsAll(archivosAntes));
                estado.setRollbackOnly();
            } catch (Exception ex) {
                throw new AssertionError(ex);
            }
        });
        assertEquals(archivosAntes, archivosDeFotos());
        assertEquals(fotoNegocio, "/api/imagenes/" + jdbc.queryForObject("select foto_lugar_ruta from emprendimiento", String.class));
        assertEquals(fotoProducto, "/api/imagenes/" + jdbc.queryForObject("select foto_producto_ruta from producto", String.class));
        mvc.perform(get(fotoNegocio)).andExpect(status().isOk());
        mvc.perform(get(fotoProducto)).andExpect(status().isOk());
    }

    private Set<Path> archivosDeFotos() throws IOException {
        try (var archivos = Files.walk(Path.of("target/test-uploads"))) {
            return new HashSet<>(archivos.filter(Files::isRegularFile).toList());
        }
    }
    @Test void solicitudesSimultaneasCreanUnProductoYUnaFoto() throws Exception {
        String token = cuenta("ana@example.com"); negocio(token);
        UUID uuid = UUID.randomUUID();
        long fotosAntes = fotosProducto();
        var inicio = new CountDownLatch(1);
        try (var pool = Executors.newFixedThreadPool(2)) {
            Callable<MvcResult> envio = () -> {
                inicio.await();
                return mvc.perform(multipartDatos("/api/emprendimientos/mio/productos", productoDatos(uuid, 0), true)
                        .header("Authorization", "Bearer " + token)).andReturn();
            };
            var a = pool.submit(envio); var b = pool.submit(envio); inicio.countDown();
            var primero = a.get(30, TimeUnit.SECONDS); var segundo = b.get(30, TimeUnit.SECONDS);
            assertEquals(Set.of(200, 201), Set.of(primero.getResponse().getStatus(), segundo.getResponse().getStatus()));
            assertEquals(datos(primero).get("id"), datos(segundo).get("id"));
        }
        assertEquals(1, jdbc.queryForObject("select count(*) from producto", Integer.class));
        assertEquals(fotosAntes + 1, fotosProducto());
    }
    private long fotosProducto() throws IOException {
        try (var archivos = Files.list(Path.of("target/test-uploads/productos"))) { return archivos.count(); }
    }
    @Test void aceptaJpegYWebpRealesYLosSirveComoPng() throws Exception {
        String token = cuenta("ana@example.com"); negocio(token);
        for (String formato : List.of("jpeg", "webp")) {
            var respuesta = mvc.perform(multipartDatos("/api/emprendimientos/mio/productos", productoDatos(UUID.randomUUID(), 0), false)
                    .file(new MockMultipartFile("foto", "camara." + formato, "image/" + formato, imagen(3, 3, formato)))
                    .header("Authorization", "Bearer " + token)).andExpect(status().isCreated()).andReturn();
            var foto = mvc.perform(get(datos(respuesta).get("fotoUrl").asText())).andExpect(status().isOk())
                    .andExpect(content().contentType("image/png")).andReturn().getResponse().getContentAsByteArray();
            assertArrayEquals(new byte[]{(byte) 0x89, 0x50, 0x4e, 0x47}, Arrays.copyOf(foto, 4));
        }
    }
    @Test void rechazaImagenInvalidaDimensionesYRutaArbitrariaYCompensaRollback() throws Exception {
        String token = cuenta("ana@example.com");
        mvc.perform(multipartDatos("/api/emprendimientos", negocioDatos(true), false)
                .file(new MockMultipartFile("foto", "falsa.png", "image/png", new byte[]{1, 2, 3}))
                .header("Authorization", "Bearer " + token)).andExpect(status().isBadRequest());
        assertThrows(ApiException.class, () -> imagenes.validar(new MockMultipartFile("foto", "ancha.png", "image/png", imagen(8193, 1))));
        assertThrows(ApiException.class, () -> imagenes.leer("productos/../../pom.xml"));
        mvc.perform(get("/api/imagenes/productos/pom.xml")).andExpect(status().isNotFound());
        var tx = new TransactionTemplate(transacciones);
        String[] guardada = new String[1];
        tx.executeWithoutResult(estado -> {
            guardada[0] = imagenes.guardar("productos", imagenes.validar(new MockMultipartFile("foto", "foto.png", "image/png", png)), null);
            assertTrue(Files.exists(Path.of("target/test-uploads", guardada[0])));
            estado.setRollbackOnly();
        });
        assertFalse(Files.exists(Path.of("target/test-uploads", guardada[0])));
    }
    @Test void esquemaSoloCuatroEntidadesYRestriccionesReales() throws Exception {
        assertEquals(Set.of("usuario", "categoria", "emprendimiento", "producto"),
                new HashSet<>(jdbc.queryForList("select table_name from information_schema.tables where table_schema='public' and table_type='BASE TABLE'", String.class)));
        String token = cuenta("ana@example.com"); negocio(token); alta(token, UUID.randomUUID(), 0, 201);
        assertThrows(org.springframework.dao.DataIntegrityViolationException.class, () -> jdbc.update("update producto set precio=-1"));
        assertThrows(org.springframework.dao.DataIntegrityViolationException.class, () -> jdbc.update("update emprendimiento set latitud=91"));
        assertThrows(org.springframework.dao.DataIntegrityViolationException.class, () -> jdbc.update("update producto set alta_hash='invalido'"));
        assertThrows(org.springframework.dao.DuplicateKeyException.class, () -> jdbc.update("""
                insert into producto(emprendimiento_id, cliente_uuid, nombre, descripcion, precio, foto_producto_ruta, alta_hash)
                select emprendimiento_id, cliente_uuid, nombre, descripcion, precio, foto_producto_ruta, alta_hash from producto
                """));
        assertThrows(org.springframework.dao.DuplicateKeyException.class, () -> jdbc.update("""
                insert into usuario(nombre, correo, contrasena_hash) select nombre, correo, contrasena_hash from usuario
                """));
        assertEquals(4, datos(mvc.perform(get("/api/public/categorias")).andExpect(status().isOk()).andReturn()).size());
    }
}
