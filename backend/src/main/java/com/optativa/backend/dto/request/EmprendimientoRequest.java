package com.optativa.backend.dto.request;

import jakarta.validation.constraints.*;
import java.math.BigDecimal;

public record EmprendimientoRequest(
        @NotNull @Positive Long categoriaId,
        @NotBlank @Size(max = 150) String nombre,
        @NotBlank String descripcion,
        @Size(max = 30) String telefono,
        @NotBlank(groups = Alta.class) @Size(max = 255) @Pattern(regexp = "(?s).*\\S.*") String direccionReferencia,
        @NotBlank(groups = Alta.class) @Size(max = 255) @Pattern(regexp = "(?s).*\\S.*") String horarioAtencion,
        @NotNull @DecimalMin("-90") @DecimalMax("90") @Digits(integer = 3, fraction = 7) BigDecimal latitud,
        @NotNull @DecimalMin("-180") @DecimalMax("180") @Digits(integer = 3, fraction = 7) BigDecimal longitud,
        @NotNull Boolean publicado) {
    public interface Alta {}
}
