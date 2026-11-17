package com.optativa.backend.dto.response;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.optativa.backend.model.Producto;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

public record ProductoResponse(Long id, Long emprendimientoId, @JsonProperty("cliente_uuid") UUID clienteUuid,
        String nombre, String descripcion, BigDecimal precio, String fotoUrl, boolean publicado,
        Instant creadoEn, Instant actualizadoEn) {
    public static ProductoResponse de(Producto p) {
        boolean visible = p.isPublicado() && p.getEmprendimiento().isPublicado();
        String prefijoFoto = visible ? "/api/imagenes/" : "/api/imagenes-privadas/";
        return new ProductoResponse(p.getId(), p.getEmprendimiento().getId(), p.getClienteUuid(), p.getNombre(),
                p.getDescripcion(), p.getPrecio(), prefijoFoto + p.getFotoProductoRuta(), p.isPublicado(),
                p.getCreadoEn(), p.getActualizadoEn());
    }
}
