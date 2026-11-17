package com.optativa.backend.service.impl;

import com.optativa.backend.dto.response.*;
import com.optativa.backend.exception.ApiException;
import com.optativa.backend.repository.*;
import com.optativa.backend.service.CatalogoService;
import com.optativa.backend.validation.Paginacion;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.*;

@Service @RequiredArgsConstructor @Transactional(readOnly = true)
public class CatalogoServiceImpl implements CatalogoService {
    private final CategoriaRepository categorias;
    private final EmprendimientoRepository emprendimientos;
    private final ProductoRepository productos;

    @Override public List<CategoriaPublica> categorias() {
        return categorias.findByActivaTrueOrderByNombreAsc().stream().map(c -> new CategoriaPublica(c.getId(), c.getNombre())).toList();
    }
    @Override public PaginaResponse<EmprendimientoResponse> emprendimientos(String nombre, Long categoriaId, int page, int size) {
        if (nombre.length() > 150 || (categoriaId != null && categoriaId < 1)) throw ApiException.invalido("Filtro inválido.");
        String filtro = "%" + nombre.strip().toLowerCase(Locale.ROOT).replace("!", "!!").replace("%", "!%").replace("_", "!_") + "%";
        return PaginaResponse.de(emprendimientos.buscarPublicados(filtro, categoriaId, Paginacion.de(page, size)).map(EmprendimientoResponse::de));
    }
    @Override public EmprendimientoResponse detalle(Long id) {
        return EmprendimientoResponse.de(emprendimientos.findByIdAndPublicadoTrue(id)
                .orElseThrow(() -> ApiException.noEncontrado("Emprendimiento no publicado o inexistente.")));
    }
    @Override public PaginaResponse<ProductoPublicoResponse> productos(Long id, int page, int size) {
        detalle(id);
        return PaginaResponse.de(productos.findByEmprendimientoIdAndPublicadoTrueAndEmprendimientoPublicadoTrue(id, Paginacion.de(page, size))
                .map(ProductoPublicoResponse::de));
    }
    @Override public void verificarImagenPublica(String ruta) {
        if (!emprendimientos.existsByFotoLugarRutaAndPublicadoTrue(ruta)
                && !productos.existsByFotoProductoRutaAndPublicadoTrueAndEmprendimientoPublicadoTrue(ruta))
            throw ApiException.noEncontrado("Fotografía no publicada.");
    }
}
