package com.optativa.backend.dto.response;

import com.optativa.backend.model.Emprendimiento;
import java.math.BigDecimal;
import java.time.Instant;

public record EmprendimientoResponse(Long id, Long categoriaId, String categoria, String nombre, String descripcion,
        String telefono, String direccionReferencia, String horarioAtencion, BigDecimal latitud, BigDecimal longitud, String fotoUrl, boolean publicado,
        Instant creadoEn, Instant actualizadoEn) {
    public static EmprendimientoResponse de(Emprendimiento e) {
        return new EmprendimientoResponse(e.getId(), e.getCategoria().getId(), e.getCategoria().getNombre(),
                e.getNombre(), e.getDescripcion(), e.getTelefono(), e.getDireccionReferencia(), e.getHorarioAtencion(),
                e.getLatitud(), e.getLongitud(),
                (e.isPublicado() ? "/api/imagenes/" : "/api/imagenes-privadas/") + e.getFotoLugarRuta(),
                e.isPublicado(), e.getCreadoEn(), e.getActualizadoEn());
    }
}
