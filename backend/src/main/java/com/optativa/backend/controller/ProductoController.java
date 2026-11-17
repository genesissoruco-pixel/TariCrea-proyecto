package com.optativa.backend.controller;

import com.optativa.backend.dto.request.*;
import com.optativa.backend.dto.response.ApiResponse;
import com.optativa.backend.service.ProductoService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController @RequestMapping("/api/emprendimientos/mio/productos") @RequiredArgsConstructor
public class ProductoController {
    private final ProductoService productos;
    @GetMapping
    public ApiResponse<?> propios(@RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "12") int size) {
        return ApiResponse.ok("Mis productos.", productos.propios(page, size));
    }
    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<?> crear(@Valid @RequestPart("datos") ProductoCrearRequest datos, @RequestPart("foto") MultipartFile foto) {
        var resultado = productos.crear(datos, foto);
        return ResponseEntity.status(resultado.creado() ? HttpStatus.CREATED : HttpStatus.OK)
                .body(ApiResponse.ok(resultado.creado() ? "Producto registrado." : "Alta ya confirmada.", resultado.producto()));
    }
    @PutMapping(value = "/{id}", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ApiResponse<?> editar(@PathVariable Long id, @Valid @RequestPart("datos") ProductoEditarRequest datos,
                                @RequestPart(value = "foto", required = false) MultipartFile foto) {
        return ApiResponse.ok("Producto actualizado.", productos.editar(id, datos, foto));
    }
}
