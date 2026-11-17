package com.optativa.backend.controller;

import com.optativa.backend.dto.response.ApiResponse;
import com.optativa.backend.service.CatalogoService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@RestController @RequestMapping("/api/public") @RequiredArgsConstructor
public class CatalogoController {
    private final CatalogoService catalogo;
    @GetMapping("/categorias")
    public ApiResponse<?> categorias() { return ApiResponse.ok("Categorías activas.", catalogo.categorias()); }
    @GetMapping("/emprendimientos")
    public ApiResponse<?> emprendimientos(@RequestParam(defaultValue = "") String nombre,
            @RequestParam(required = false) Long categoriaId, @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "12") int size) {
        return ApiResponse.ok("Emprendimientos publicados.", catalogo.emprendimientos(nombre, categoriaId, page, size));
    }
    @GetMapping("/emprendimientos/{id}")
    public ApiResponse<?> detalle(@PathVariable Long id) { return ApiResponse.ok("Emprendimiento.", catalogo.detalle(id)); }
    @GetMapping("/emprendimientos/{id}/productos")
    public ApiResponse<?> productos(@PathVariable Long id, @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "12") int size) {
        return ApiResponse.ok("Productos publicados.", catalogo.productos(id, page, size));
    }
}
