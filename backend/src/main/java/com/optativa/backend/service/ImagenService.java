package com.optativa.backend.service;

import com.optativa.backend.exception.ApiException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.*;
import org.springframework.web.multipart.MultipartFile;
import javax.imageio.*;
import javax.imageio.stream.MemoryCacheImageInputStream;
import java.awt.image.BufferedImage;
import java.io.*;
import java.nio.file.*;
import java.util.*;

@Service @Slf4j
public class ImagenService {
    private final Path raiz;
    private final int maxBytes;
    private final int maxDimension;
    private final long maxPixeles;

    public record Imagen(byte[] original, BufferedImage contenido) {}

    public ImagenService(@Value("${app.images.directory}") String directorio,
                         @Value("${app.images.max-bytes}") int maxBytes,
                         @Value("${app.images.max-dimension}") int maxDimension,
                         @Value("${app.images.max-pixels}") long maxPixeles) throws IOException {
        this.maxBytes = maxBytes;
        this.maxDimension = maxDimension;
        this.maxPixeles = maxPixeles;
        if (maxBytes < 1 || maxBytes == Integer.MAX_VALUE || maxDimension < 1 || maxPixeles < 1)
            throw new IllegalArgumentException("Límites de imagen inválidos");
        Path configurada = Path.of(directorio).toAbsolutePath().normalize();
        Files.createDirectories(configurada);
        this.raiz = configurada.toRealPath();
        for (String grupo : List.of("emprendimientos", "productos")) {
            Path carpeta = raiz.resolve(grupo);
            Files.createDirectories(carpeta);
            if (Files.isSymbolicLink(carpeta) || !carpeta.toRealPath().getParent().equals(raiz))
                throw new IOException("Directorio de imágenes inválido");
        }
    }

    public Imagen validar(MultipartFile archivo) {
        if (archivo == null || archivo.isEmpty()) throw ApiException.invalido("La fotografía es obligatoria.");
        if (archivo.getSize() > maxBytes) throw ApiException.invalido("La fotografía supera 5 MB.");
        String nombre = Objects.toString(archivo.getOriginalFilename(), "");
        int punto = nombre.lastIndexOf('.');
        if (punto < 1) throw ApiException.invalido("La fotografía debe tener una extensión válida.");
        String extension = nombre.substring(punto + 1).toLowerCase(Locale.ROOT);
        String formato = "jpg".equals(extension) ? "jpeg" : extension;
        if (!Set.of("jpg", "jpeg", "png", "webp").contains(extension)
                || !("image/" + formato).equalsIgnoreCase(archivo.getContentType()))
            throw ApiException.invalido("Envíe JPG, PNG o WebP con extensión y MIME coincidentes.");
        try (var entrada = archivo.getInputStream()) {
            byte[] bytes = entrada.readNBytes(maxBytes + 1);
            if (bytes.length > maxBytes) throw ApiException.invalido("La fotografía supera 5 MB.");
            try (var stream = new MemoryCacheImageInputStream(new ByteArrayInputStream(bytes))) {
                var lectores = ImageIO.getImageReaders(stream);
                if (!lectores.hasNext()) throw ApiException.invalido("El archivo no contiene una imagen válida.");
                var lector = lectores.next();
                try {
                    lector.setInput(stream, true, true);
                    if (!formato.equalsIgnoreCase(lector.getFormatName()))
                        throw ApiException.invalido("El contenido no coincide con el formato de la fotografía.");
                    int ancho = lector.getWidth(0);
                    int alto = lector.getHeight(0);
                    if (ancho < 1 || alto < 1 || ancho > maxDimension || alto > maxDimension || (long) ancho * alto > maxPixeles)
                        throw ApiException.invalido("La fotografía supera las dimensiones o píxeles permitidos.");
                    BufferedImage imagen = lector.read(0);
                    if (imagen == null) throw ApiException.invalido("Fotografía inválida.");
                    return new Imagen(bytes, imagen);
                } finally { lector.dispose(); }
            }
        } catch (ApiException ex) {
            throw ex;
        } catch (IOException | RuntimeException ex) {
            throw ApiException.invalido("No se pudo decodificar la fotografía.");
        } catch (LinkageError ex) {
            throw new ApiException(org.springframework.http.HttpStatus.SERVICE_UNAVAILABLE, "El decodificador WebP no está disponible.");
        }
    }

    public String guardar(String grupo, Imagen imagen, String anterior) {
        if (!TransactionSynchronizationManager.isActualTransactionActive()
                || !TransactionSynchronizationManager.isSynchronizationActive())
            throw new IllegalStateException("La escritura de fotos requiere una transacción.");
        String relativa = grupo + "/" + UUID.randomUUID() + ".png";
        Path destino = rutaSegura(relativa);
        boolean creado = false;
        try {
            // CREATE_NEW impide que una colisión o enlace existente sobrescriba otro archivo.
            try (var salida = Files.newOutputStream(destino, StandardOpenOption.CREATE_NEW, StandardOpenOption.WRITE)) {
                creado = true;
                if (!ImageIO.write(imagen.contenido(), "png", salida)) throw new IOException("Codificador PNG no disponible");
            }
        } catch (IOException | RuntimeException ex) {
            if (creado) eliminar(relativa);
            log.error("No se pudo escribir la fotografía {}", relativa, ex);
            throw new ApiException(org.springframework.http.HttpStatus.SERVICE_UNAVAILABLE, "No se pudo guardar la fotografía.");
        }
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override public void afterCompletion(int status) {
                if (status == STATUS_COMMITTED) {
                    if (anterior != null) eliminar(anterior);
                } else if (status == STATUS_ROLLED_BACK) {
                    eliminar(relativa);
                } else {
                    log.warn("Resultado de transacción desconocido para la fotografía {}", relativa);
                }
            }
        });
        return relativa;
    }

    public Resource leer(String relativa) {
        Path ruta = rutaSegura(relativa);
        if (!Files.isRegularFile(ruta, LinkOption.NOFOLLOW_LINKS)) throw ApiException.noEncontrado("Fotografía no encontrada.");
        return new FileSystemResource(ruta);
    }

    private Path rutaSegura(String relativa) {
        if (relativa == null || !relativa.matches("(emprendimientos|productos)/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\\.png"))
            throw ApiException.noEncontrado("Ruta de fotografía inválida.");
        Path ruta = raiz.resolve(relativa).normalize();
        try {
            if (!ruta.startsWith(raiz) || Files.isSymbolicLink(ruta) || Files.isSymbolicLink(ruta.getParent())
                    || !ruta.getParent().toRealPath().getParent().equals(raiz))
                throw ApiException.noEncontrado("Ruta de fotografía inválida.");
        } catch (IOException ex) { throw ApiException.noEncontrado("Ruta de fotografía no disponible."); }
        return ruta;
    }

    private void eliminar(String relativa) {
        try { Files.deleteIfExists(rutaSegura(relativa)); }
        catch (IOException | ApiException ex) { log.error("No se pudo limpiar la fotografía {}", relativa); }
    }
}
