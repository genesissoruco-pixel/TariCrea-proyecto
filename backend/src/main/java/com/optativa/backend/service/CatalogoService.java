package com.optativa.backend.service;

import com.optativa.backend.dto.response.*;
import java.util.List;

public interface CatalogoService {
    record CategoriaPublica(Long id, String nombre) {}
    List<CategoriaPublica> categorias();
    PaginaResponse<EmprendimientoResponse> emprendimientos(String nombre, Long categoriaId, int page, int size);
    EmprendimientoResponse detalle(Long id);
    PaginaResponse<ProductoPublicoResponse> productos(Long id, int page, int size);
    void verificarImagenPublica(String ruta);
}
