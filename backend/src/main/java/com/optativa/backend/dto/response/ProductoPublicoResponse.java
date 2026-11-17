package com.optativa.backend.dto.response;

import com.optativa.backend.model.Producto;
import java.math.BigDecimal;

public record ProductoPublicoResponse(Long id, Long emprendimientoId, String nombre, String descripcion,
        BigDecimal precio, String fotoUrl) {
    public static ProductoPublicoResponse de(Producto p) {
        return new ProductoPublicoResponse(p.getId(), p.getEmprendimiento().getId(), p.getNombre(),
                p.getDescripcion(), p.getPrecio(), "/api/imagenes/" + p.getFotoProductoRuta());
    }
}
