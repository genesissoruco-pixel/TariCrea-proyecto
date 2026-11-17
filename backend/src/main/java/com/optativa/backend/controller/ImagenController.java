package com.optativa.backend.controller;

import com.optativa.backend.service.*;
import com.optativa.backend.exception.ApiException;
import com.optativa.backend.repository.EmprendimientoRepository;
import com.optativa.backend.repository.ProductoRepository;
import com.optativa.backend.security.UsuarioActual;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.Resource;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;

@RestController @RequiredArgsConstructor
public class ImagenController {
    private final ImagenService imagenes;
    private final CatalogoService catalogo;
    private final EmprendimientoRepository emprendimientos;
    private final ProductoRepository productos;
    private final UsuarioActual actual;

    @GetMapping("/api/imagenes/{grupo:emprendimientos|productos}/{nombre}")
    public ResponseEntity<Resource> imagen(@PathVariable String grupo, @PathVariable String nombre) {
        String ruta = grupo + "/" + nombre;
        catalogo.verificarImagenPublica(ruta);
        return responder(imagenes.leer(ruta), nombre);
    }

    @GetMapping("/api/imagenes-privadas/{grupo:emprendimientos|productos}/{nombre}")
    public ResponseEntity<Resource> imagenPropia(@PathVariable String grupo, @PathVariable String nombre) {
        String ruta = grupo + "/" + nombre;
        Long usuarioId = actual.id();
        boolean propia = grupo.equals("productos")
                ? productos.existsByFotoProductoRutaAndEmprendimientoUsuarioId(ruta, usuarioId)
                : emprendimientos.existsByFotoLugarRutaAndUsuarioId(ruta, usuarioId);
        if (!propia) throw ApiException.noEncontrado("Fotografía no encontrada.");
        return responder(imagenes.leer(ruta), nombre);
    }

    private ResponseEntity<Resource> responder(Resource archivo, String nombre) {
        return ResponseEntity.ok().contentType(MediaType.IMAGE_PNG).cacheControl(CacheControl.noStore())
                .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"" + nombre + "\"")
                .body(archivo);
    }
}
